require 'addressable/uri'
require 'httpclient'
require 'openssl'
require 'cinch/formatting'

module VikiLinkBot

  class StatusChecker
    include Cinch::Plugin

    # FIXME: add global config
    @reference_hosts = %w( en.wikipedia.org www.google.com )
    @monitored_hosts = %w( fr es it en ca eu scn www download ).map { |s| "#{s}.vikidia.org" }
    @httpc = HTTPClient.new
    @httpc.receive_timeout = 10  # if the site does not respond in under this delay, it likely has a problem
    # @httpc.redirect_uri_callback = ->(_, res) { res.header['location'][0] }  # FIXME: fix Vikidia's redirects
    @max_redirects = 5
    @expected_cert = OpenSSL::X509::Certificate.new(File.read(::MISCPATH + '/vikidia.pem'))
    @last_statuses = nil
    @acknowledged_errors = {}

    class << self
      attr_accessor :last_statuses
    end

    def initialize(*args)
      super
      @in_progress = Mutex.new  # locked when a thread is performing checks; other threads then simply give up
    end

    # Run the notify_all method each 20 seconds.
    timer 20, method: :notify_all  # FIXME: add global config

    # Check @monitored_hosts' statuses and alert all channels the bot is in if necessary.
    def notify_all
      cls = self.class
      @in_progress.try_synchronize do
        errors = cls.filter_errors(cls.find_errors)
        return if errors == cls.last_statuses
        cls.last_statuses = errors
        msg = cls.format_errors(errors)
        bot.channels.each do |chan|
          chan.send(msg)
        end
      end
    end

    # @param [String] host
    # @return [TrueClass,FalseClass] whether the acknowledgement was valid and thus recorded
    def self.ack_last_error(host)
      return false unless @last_statuses.keys.include?(host)
      @acknowledged_errors[host] = @last_statuses[host]
      true
    end

    # Returns a string describing the statuses, or nil if the argument was nil.
    # @param [Hash, nil] statuses from find_errors
    # @return [String, nil]
    def self.format_errors(statuses)
      merged = Hash.new { |h, k| h[k] = [] }
      statuses.each do |host, status|
        merged[status] << host unless status.nil?
      end
      msg = merged.map { |status, hosts| "#{hosts.join(', ')}: " + Cinch::Formatting.format(:red, status) }.
                   join(' | ')
      '[VSC] ' + (msg.empty? ? Cinch::Formatting.format(:green, '✓') : msg)
    end

    # Returns nil if the argument is the same as @last_statuses; otherwise updates @last_statuses and returns it.
    # @param [Hash] new_statuses from find_errors
    # @return [Hash, nil]
    def self.filter_errors(new_statuses)
      # We watch reference sites so we can tell when a status is due to vlb's
      # connection. Here we remove reports of problems shared by our reference
      # sites, because these problems are likely to be on vlb's side.
      ref_statuses = new_statuses.select { |host, _| @reference_hosts.include?(host) }.map { |_, v| v }.uniq
      new_statuses.delete_if { |_, status| ref_statuses.include?(status) }

      # Ignore acknowledged errors in further processing
      # (but we remember them anyway, so that we can drop the acknowledgement if an error disappears).
      # Note: Even if it may seem counter-intuitive, using #delete_if instead of #each allows us to safely delete
      # what we are iterating on.
      @acknowledged_errors.delete_if do |host, status|
        if new_statuses[host] == status
          new_statuses.delete(host)
          false
        else
          true
        end
      end

      new_statuses
    end

    # Find potential errors for sites specified in @monitored_hosts.
    # @return [Hash<Addressable::URI, Exception>] a URL => exception mapping. The exception part is nil if no errors were found.
    def self.find_errors
      statuses = {}
      lock = Mutex.new
      threads = []
      [*@monitored_hosts, *@reference_hosts].shuffle.each do |uri|
        threads << Thread.new do
          res = begin
            redirects = 0
            r = @httpc.head('https://' + uri)
            while r.redirect?
              redirects += 1
              raise SocketError.new("trop de redirections (#{redirects})") if redirects > @max_redirects
              r = @httpc.head(r.headers['Location'])  # retry
            end
            unless @reference_hosts.include?(uri)
              [:check_http_status, :check_tls_cert].each { |f| send(f, r) }
            end
            nil
          rescue HTTPClient::ReceiveTimeoutError
            "délai d'attente écoulé (#{@httpc.receive_timeout} s)"
          rescue => e
            e
          end
          lock.synchronize do
            # force stringification because it will be compared later
            statuses[uri] = res.nil? ? nil : res.to_s
          end
        end
      end
      threads.each(&:join)
      statuses
    end

    def self.check_http_status(r)
      raise "statut HTTP inattendu (#{r.status})" if r.status / 100 != 2
    end

    def self.check_tls_cert(r)
      cert = r.peer_cert
      raise 'pas de certificat TLS' if cert.nil?

      now = Time.now
      not_before, not_after = cert.not_before, cert.not_after
      raise "certificat invalide : inutilisable avant #{not_before}" if not_before > now
      raise "certificat invalide : inutilisable après #{not_after}" if not_after < now

      raise 'le certificat a changé' if cert.to_s != @expected_cert.to_s
    end

  end

end

class Mutex
  def try_synchronize
    return unless try_lock
    begin
      yield
    ensure
      unlock
    end
  end
end
