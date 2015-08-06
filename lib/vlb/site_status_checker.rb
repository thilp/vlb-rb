require 'addressable/uri'
require 'httpclient'
require 'openssl'

module VikiLinkBot

  class StatusChecker
    include Cinch::Plugin

    def initialize(*args)
      super
      @monitored_sites = %w( fr es it en ca eu ru scn ).map { |s| Addressable::URI.parse("https://#{s}.vikidia.org") }
      @httpc = HTTPClient.new
      # @httpc.redirect_uri_callback = ->(_, res) { res.header['location'][0] }  # FIXME: fix Vikidia's redirects
      @max_redirects = 5
      @expected_cert = OpenSSL::X509::Certificate.new(File.read(::MISCPATH + '/vikidia.pem'))  # FIXME: add global config
      @last_statuses = nil
    end

    # Run the notify_all method each 20 seconds.
    timer 20, method: :notify_all

    # Check @monitored_sites' statuses and alert all channels the bot is in if necessary.
    def notify_all
      msg = format_errors(filter_errors(find_errors))
      return if msg.nil?
      bot.channels.each do |chan|
        chan.send(msg)
      end
    end

    # Returns a string describing the statuses, or nil if the argument was nil.
    # @param [Hash, nil] statuses from find_errors
    # @return [String, nil]
    def format_errors(statuses)
      return if statuses.nil?
      msg = statuses.reject { |_, status| status.nil? }.
                     map { |uri, status| "#{uri.host}: " + Format(:red, status.message) }.
                     join(' | ')
      '[VSC] ' + (msg.empty? ? Format(:green, '✓') : msg)
    end

    # Returns nil if the argument is the same as @last_statuses; otherwise updates @last_statuses and returns it.
    # @param [Hash] new_statuses from find_errors
    # @return [Hash, nil]
    def filter_errors(new_statuses)
      return if new_statuses == @last_statuses
      @last_statuses = new_statuses
    end

    # Find potential errors for sites specified in @monitored_sites.
    # @return [Hash<Addressable::URI, Exception>] a URL => exception mapping. The exception part is nil if no errors were found.
    def find_errors
      statuses = {}
      @monitored_sites.each do |uri|
        statuses[uri] = begin
          redirects = 0
          r = @httpc.head(uri)
          while r.redirect?
            redirects += 1
            raise SocketError.new('too many redirects') if redirects > @max_redirects
            r = @httpc.head(r.headers['Location'])
          end
          [:check_http_status, :check_tls_cert].each { |f| send(f, r) }
          nil
        rescue => e
          e
        end
      end
      statuses
    end

    def check_http_status(r)
      raise "unexpected HTTP status #{r.status}" if r.status / 100 != 2
    end

    def check_tls_cert(r)
      cert = r.peer_cert
      raise 'no TLS certificate' if cert.nil?

      now = Time.now
      not_before, not_after = cert.not_before, cert.not_after
      raise "invalid certificate validity: #{not_before} is after today" if not_before > now
      raise "invalid certificate validity: #{not_after} is before today" if not_after < now

      raise 'the certificate has changed' if cert != @expected_cert
    end

  end

end
