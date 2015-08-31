require 'cinch/formatting'
require 'cinch/logger'
require 'httpclient'
require 'jsonclient'
require 'addressable/uri'
require 'addressable/template'

class WikiFactory

  class << self
    def instance  # WikiFactory is a singleton object
      @instance = self.new unless @instance
      @instance
    end
  end

  attr_reader :httpc, :jsonc, :wikis

  def initialize
    @httpc = HTTPClient.new
    @jsonc = JSONClient.new
    [@httpc, @jsonc].each do |c|
      c.redirect_uri_callback = ->(_, res) { res.header['location'][0] } # FIXME
    end
    @wikis = {}
  end
  private :initialize

  def get(domain=nil)
    domain = domain ? domain.chomp : ''
    unless domain.include? '.'
      domain = case domain
                 when ''
                   'fr.vikidia.org'
                 when 'w', 'wp'
                   'fr.wikipedia.org'
                 when /^(\w+)wp$/, /^(simple)$/
                   "#{$1}.wikipedia.org"
                 when /^(\w+)wikt$/
                   "#{$1}.wiktionary.org"
                 when 'meta'
                   'meta.wikimedia.org'
                 else
                   "#{domain}.vikidia.org"
               end
    end
    @wikis[domain] ||= new_from_domain(domain)
  end

  def new_from_domain(domain)
    if domain.end_with? '.vikidia.org', '.wikipedia.org'
      Wiki.new "https://#{domain}", '/w/api.php', '/wiki', self
    else
      begin
        r, redirects, max_redirects = @httpc.get(final_url = 'http://' + domain), 0, 5
        while r.redirect?
          redirects += 1
          raise SocketError.new('too many redirects') if redirects > max_redirects
          r = @httpc.get(final_url = r.headers['Location'])
        end
      rescue SocketError => err
        raise "impossible de contacter #{domain}: #{err.message}"
      else
        article_path = (final_url =~ %r{ ^ https?:// [^/]+ ([^?]*) }x) ?
            $1.split('/')[0..-2].join('/') :
            '/wiki'
        if r.body.scrub =~ %r{ ^ <link \s+ rel="EditURI" .+? href=" ( (?:https?:)?//[^/]+ ) ([^"?]+) }x
          api_url, api_path = $1, $2
          url = api_url.start_with?('//') ? 'https:' + api_url : api_url
          Wiki.new url, api_path, article_path, self
        else
          if @httpc.get('http://' + domain + '/w/api.php').ok?  # last chance!
            Wiki.new('http://' + domain, '/w/api.php', article_path, self)
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
    puts "Wiki#api request to #{@api_url} with params #{params_hash}"
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
  attr_reader :wiki, :pagename
  attr_accessor :state

  def initialize(wiki, pagename, check)
    @wiki = wiki
    @pagename = pagename
    @state = check ? 1 : 0
  end

  def to_s
    url = wiki.article_url(pagename)
    if state && state >= 200
      format = [[:green, '∃'], [:teal, '↳'], [:red, '∄'], [:orange, '?']][state / 100 - 2]
      prefix = Cinch::Formatting.format(format.first, format.last)
      "#{prefix} #{url}"
    else
      url.to_s
    end
  end

end