require 'cinch/formatting'
require 'cinch/logger'
require 'httpclient'
require 'jsonclient'
require 'addressable/uri'
require 'addressable/template'

class WikiFactory

  attr_reader :httpc, :jsonc, :wikis, :loggers

  # @param [Cinch::LoggerList] loggers
  def initialize(loggers)
    @loggers = loggers
    @httpc = HTTPClient.new
    @jsonc = JSONClient.new
    [@httpc, @jsonc].each do |c|
      c.redirect_uri_callback = ->(_, res) { res.header['location'][0] } # FIXME
    end
    @wikis = {}
  end

  def get(domain=nil)
    domain = domain ? domain.chomp : ''
    unless domain.include? '.'
      domain = case domain
                 when ''
                   'fr.vikidia.org'
                 when 'wp'
                   'fr.wikipedia.org'
                 when /^(\w+)wp$/, /^(simple)$/
                   "#{$1}.wikipedia.org"
                 when 'meta'
                   'meta.wikimedia.org'
                 else
                   "#{domain}.vikidia.org"
               end
    end
    @wikis[domain] ||= new_from_domain(domain)
  end

  def new_from_domain(domain)
    loggers.info "Creating new Wiki object for domain #{domain}"
    if domain.end_with? '.vikidia.org', '.wikipedia.org'
      Wiki.new "https://#{domain}", '/w/api.php', '/wiki', self
    else
      begin
        m_api, m_articles = nil, nil
        @httpc.get_content('http://' + domain) do |chunk|
          chunk.scrub! '<?INVALID ENCODING!?>'
          m_api ||= %r{^<link rel="EditURI".+?href="((?:https?:)?//[^/]+)([^"?]+)}.match chunk
          m_articles ||= %r{^<link rel="alternate" hreflang="x-default" href="((/[^"/]+)+)/}.match chunk
          break if m_api && m_articles
        end
      rescue SocketError => err
        raise "impossible de contacter #{domain}: #{err.message}"
      else
        if m_api
          url = m_api[1].start_with?('//') ? 'https:' + m_api[1] : m_api[1]
          Wiki.new url, m_api[2], (m_articles ? m_articles[1] : ''), self
        else
          if @httpc.get('http://' + domain + '/w/api.php').ok?  # last chance!
            Wiki.new('http://' + domain, '/w/api.php', '/wiki', self)
          else
            raise "impossible de trouver l'API de #{domain}"
          end
        end
      end
    end
  end
end

class DummyEscaper
  def self.transform(name, value)
    value
  end
end

class Wiki
  attr_reader :base_url, :factory

  def initialize(uri, api_path, article_path, factory)
    @base_url = uri.is_a?(Addressable::URI) ? uri : Addressable::URI.parse(uri)
    @api_url = Addressable::URI.parse(@base_url.to_s + api_path).normalize!
    @article_template = Addressable::Template.new(@base_url.to_s + article_path + '/{article}')
    @factory = factory
  end

  def api(params_hash)
    method = params_hash.key?(:method) ? params_hash.delete(:method) : :get
    params_hash[:format] = 'json'
    factory.loggers.info "Sending API request: url=#{@api_url}, parameters=#{params_hash}"
    res = @factory.jsonc.request(method, @api_url, params_hash)
    raise "#{res.status} #{res.reason}" unless res.ok?
    res.content
  end

  def article_url(pagename)
    pagename = Addressable::URI.encode_component(pagename, Addressable::URI::CharacterClasses::PATH)
    pagename.gsub!(/['*$()]/) { |c| '%' + c.ord.to_s(16) }
    @article_template.expand({article: pagename}, DummyEscaper)
  end

  def https?
    @base_url.scheme == 'https'
  end

  def scheme
    @base_url.scheme
  end

  def domain
    @base_url.host
  end

  def page_states(*pages)
    answer = api action: 'query', prop: 'info', indexpageids: 1, titles: pages.join('|')
    if answer['query'].nil? || answer['query']['pageids'].nil?
      Hash[pages.map { |p| [p, 502] }]  # 502 Bad Gateway
    else
      states = {}
      pages.zip answer['query']['pageids'] do |name, pageid|
        pagedata = answer['query']['pages'][pageid]
        states[name] = pagedata['missing'] ? 404 : pagedata['redirect'] ? 301 : 200
      end
      states
    end
  end

end


class Wikilink
  attr_reader :wiki, :pagename, :check
  attr_accessor :state

  def initialize(wiki, pagename, check)
    @wiki = wiki
    @pagename = pagename
    @check = check
  end

  def to_s
    url = wiki.article_url(pagename)
    if state
      format = [[:green, '∃'], [:teal, '↳'], [:red, '∄'], [:orange, '?']][state / 100 - 2]
      prefix = Cinch::Formatting.format(format.first, format.last)
      "#{prefix} #{url}"
    else
      url
    end
  end

end