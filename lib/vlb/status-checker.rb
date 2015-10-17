require 'addressable/uri'
require 'httpclient'
require 'openssl'
require 'cinch/formatting'

module VikiLinkBot

  class CheckResult
    attr_reader :errors, :ignore_list
    def initialize(reference_hosts, ignore_list)
      @errors = {}
      @ref_hosts = reference_hosts
      @ignore_list = ignore_list
    end

    # Returns a string describing the statuses.
    # @return [String]
    def to_s
      merged = Hash.new { |h, k| h[k] = [] }
      filtered.each do |host, status|
        merged[status] << host unless status.nil?
      end
      msg = merged.map { |status, hosts| "#{hosts.join(', ')}: " + Cinch::Formatting.format(:red, status) }.join(' | ')
      return msg unless msg.empty?
      filter_ack.size == @errors.size ? Cinch::Formatting.format(:green, '✓') : random_yellow_monkey
    end

    def filtered
      filter_own.select { |k, v| filter_ack[k] == v }  # hash intersection
    end

    def filter_ack
      @f_ack ||= @errors.select { |k, v| !@ignore_list.key?(k) || @ignore_list[k] != v }
    end

    def filter_own
      @f_own ||= begin
        ref_statuses = @errors.select { |host, _| @ref_hosts.include?(host) }.map { |_, v| v }.uniq
        @errors.reject { |_, status| ref_statuses.include?(status) }
      end
    end

    def keys
      @errors.keys
    end

    def values
      @errors.values
    end

    def [](key)
      @errors[key]
    end

    def []=(key, value)
      @errors[key] = value
    end

    def random_yellow_monkey
      Cinch::Formatting.format(:yellow, (0x1F648..0x1F64A).to_a.shuffle.take(1).pack('U'))
    end

    def ==(other)
      other.class == self.class && other.errors == self.errors
    end
  end

  class StatusChecker
    include Cinch::Plugin

    # FIXME: add global config
    @ref_hosts = %w( en.wikipedia.org www.google.com )
    @monitored_hosts = %w( fr es it en ca eu scn www download ).map { |s| "#{s}.vikidia.org" }
    @httpc = HTTPClient.new
    @httpc.receive_timeout = 10  # if the site does not respond in under this delay, it likely has a problem
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
        errors = cls.find_errors
        return if errors == cls.last_statuses
        cls.last_statuses = errors
        msg = "[VSC] #{errors}"
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

    # Find potential errors for sites specified in @monitored_hosts.
    # @return [VikiLinkBot::CheckResult] a URL => exception mapping. The exception part is nil if no errors were found.
    def self.find_errors
      statuses = VikiLinkBot::CheckResult.new(@ref_hosts, @acknowledged_errors)
      lock = Mutex.new
      threads = []
      [*@monitored_hosts, *@ref_hosts].shuffle.each do |uri|
        threads << Thread.new do
          res = begin
            redirects = 0
            r = @httpc.head('https://' + uri)
            while r.redirect?
              redirects += 1
              raise SocketError.new("trop de redirections (#{redirects})") if redirects > @max_redirects
              r = @httpc.head(r.headers['Location'])  # retry
            end
            unless @ref_hosts.include?(uri)
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
