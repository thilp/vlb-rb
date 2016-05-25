require 'addressable/uri'
require 'httpclient'
require 'openssl'
require 'cinch/formatting'

module VikiLinkBot

  # Represents the result of a domain check: either success or failure.
  class DomainValidity
    attr_reader :uri

    def initialize(uri)
      @uri = uri
    end

    def ==(o)
      self.class == o.class &&
        self.uri == o.uri &&
        self.to_s == o.to_s
    end

    alias_method :eql?, :==

    def hash
      @uri.hash ^ to_s.hash
    end
  end

  # For domains that have been reached and that passed all tests.
  class DomainOK < DomainValidity
    def to_s
      'ok'
    end
  end

  # For domains that have not been reached even though we were technically able to do so (the problem is on their side)
  # or that failed at least a test.
  class DomainError < DomainValidity
    attr_reader :err

    def initialize(uri, acknowledged, err_msg)
      super(uri)
      @err = err_msg.to_s
      @acknowledged = !!acknowledged && @err == acknowledged.err
    end

    def acknowledged?
      @acknowledged
    end

    def to_s
      @s ||= @err.gsub(uri, '<domain>')
    end
  end

  # For domains that have not been reached because we were technically unable to (the problem is on our side).
  class UndeterminedResult < DomainValidity
    def initialize(uri, msg)
      super(uri)
      @msg = msg.to_s
    end

    def to_s
      @s ||= @msg.gsub(uri, '<domain>')
    end
  end


  # Maps an URI to its DomainValidity instance, and knows how to display itself, including acknowledged errors.
  class DomainStatusMap
    def initialize
      @statuses = {}
    end

    def problems
      @problems ||= @statuses.values.select { |status| status.is_a?(DomainError) }
    end

    # Returns a string describing the statuses.
    # @return [String]
    def to_s
      return Cinch::Formatting.format(:green, '✓') if problems.none?

      relevant_problems = problems.reject(&:acknowledged?)
      return random_green_monkey if relevant_problems.none?

      relevant_problems.group_by(&:to_s).
          map { |msg, errs| "#{errs.map(&:uri).join(', ')}: " + Cinch::Formatting.format(:red, msg) }.
          join(' | ')
    end

    def [](key)
      @statuses[key]
    end

    def []=(key, value)
      @statuses[key] = value
    end

    def random_green_monkey
      Cinch::Formatting.format(:green, (0x1F648..0x1F64A).to_a.shuffle.take(1).pack('U'))
    end

    def same_problems_than?(other)
      sp, op = self.problems, other.problems
      sp.count == op.count &&
        sp.sort_by(&:uri) == op.sort_by(&:uri)
    end
  end


  class StatusChecker
    include Cinch::Plugin

    # FIXME: add global config
    @monitored_hosts = %w( fr es it en ca eu scn www download ).map { |s| "#{s}.vikidia.org" }
    @httpc = HTTPClient.new
    @httpc.send_timeout = 1
    @httpc.connect_timeout = 1
    @httpc.receive_timeout = 5  # if the site does not respond in under this delay, it likely has a problem
    @max_redirects = 5
    @expected_cert = OpenSSL::X509::Certificate.new(File.read(::MISCPATH + '/vikidia.pem'))
    @last_statuses = nil
    @acknowledged_errors = {}

    class << self
      attr_accessor :last_statuses
    end

    def initialize(*)
      super
      @in_progress = false  # true when a thread is performing checks; other threads then simply give up
    end

    # Run the notify_all method each 20 seconds.
    timer 20, method: :notify_all  # FIXME: add global config

    # Check @monitored_hosts' statuses and alert all channels the bot is in if necessary.
    def notify_all
      # Return early if another thread is already executing this method:
      synchronize(:vsc) do
        return if @in_progress
        @in_progress = true
      end
      # If not, check whether the most recent domain statuses are different
      # from the last recorded ones (in self.class.last_statuses):
      begin
        errors = self.class.find_errors
        unless errors.same_problems_than?(self.class.last_statuses)
          log("new errors are: #{errors.instance_eval { @statuses.values }.sort_by(&:uri).inspect}")
          log("old errors are: #{self.class.last_statuses.instance_eval { @statuses.values }.sort_by(&:uri).inspect}") if self.class.last_statuses
          self.class.last_statuses = errors
          msg = "[VSC] #{errors}"
          bot.channels.each do |chan|
            chan.send(msg)
          end
        end
      ensure
        synchronize(:vsc) { @in_progress = false }
      end
    end

    # @param [String] host
    # @return [TrueClass,FalseClass] whether the acknowledgement was valid and thus recorded
    def self.ack_last_error(host)
      return false unless @last_statuses && @last_statuses[host]
      @acknowledged_errors[host] = @last_statuses[host]
      true
    end

    def self.unack(host)
      @acknowledged_errors.delete(host)
    end

    def self.acked
      @acknowledged_errors.dup
    end

    def self.make_domain_checker_thread(uri)
      Thread.new do
        begin
          nb_redirects = 0
          answer = @httpc.head('https://' + uri)
          while answer.redirect?
            nb_redirects += 1
            fail SocketError, "trop de redirections (#{nb_redirects})" if nb_redirects > @max_redirects
            answer = @httpc.head(answer.headers['Location']) # retry
          end
          [:check_http_status, :check_tls_cert].each { |f| send(f, answer) }
          DomainOK.new(uri)
        rescue HTTPClient::ReceiveTimeoutError
          DomainError.new(uri, @acknowledged_errors[uri], "délai d'attente écoulé (#{@httpc.receive_timeout} s)")
        rescue HTTPClient::TimeoutError => e
          UndeterminedResult.new(uri, e)
        rescue => e
          DomainError.new(uri, @acknowledged_errors[uri], e)
        end
      end
    end

    # Find potential errors for sites specified in @monitored_hosts.
    # @return [VikiLinkBot::DomainStatusMap] a URL => exception mapping.
    def self.find_errors
      status_map = DomainStatusMap.new
      all_statuses = []
      domains_to_check = @monitored_hosts
      2.times do
        nth_wave = domains_to_check.shuffle.map! { |uri| make_domain_checker_thread(uri) }.map!(&:value)
        all_statuses.concat(nth_wave)
      end

      # For each domain, combine the multiple results we got from above.
      # Also, if we only have an UndeterminedResult, try again one last time.
      with_status = all_statuses.group_by(&:uri)
      with_status.each do |uri, results|
        uri_result = results.find { |r| r.is_a?(DomainOK) } || results.last
        status_map[uri] = uri_result.is_a?(UndeterminedResult) ?
            make_domain_checker_thread(uri).value : # last chance
            uri_result
      end

      status_map
    end

    def self.check_http_status(r)
      fail "statut HTTP inattendu (#{r.status})" if r.status / 100 != 2
    end

    def self.check_tls_cert(r)
      cert = r.peer_cert
      fail 'pas de certificat TLS' if cert.nil?

      now = Time.now
      not_before, not_after = cert.not_before, cert.not_after
      fail "certificat invalide : inutilisable avant #{not_before}" if not_before > now
      fail "certificat invalide : inutilisable après #{not_after}" if not_after < now

      fail 'le certificat a changé' if cert.to_s != @expected_cert.to_s
    end
  end
end
