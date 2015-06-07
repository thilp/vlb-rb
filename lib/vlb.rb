require 'abbrev'
require 'cinch'
require 'httpclient'
require 'addressable/uri'
require 'damerau-levenshtein'
require 'wiki'

class VikiLinkBot
  include Cinch::Plugin

  attr_reader :httpc, :wikis # Web clients

  @version = 1
  @cmd_prefix = '!'

  class << self
    attr_reader :version, :cmd_prefix
  end

  def initialize(bot)
    super
    @httpc = HTTPClient.new
    @wikis = WikiFactory.new

    # Allowing https->http redirects, which are bad but nevertheless currently performed by *.vikidia.org
    @httpc.redirect_uri_callback = ->(_uri, res) { res.header['location'][0] }

    @commands = {
        # Simple links, no customization: we can store strings
        alerte: 'https://fr.vikidia.org/wiki/Vikidia:Alerte',
        ba: 'https://fr.vikidia.org/wiki/Vikidia:BA',
        bp: 'https://fr.vikidia.org/wiki/Vikidia:BP',
        bavardages: 'https://fr.vikidia.org/wiki/Vikidia:Bavardages',
        cabane: 'https://fr.vikidia.org/wiki/Vikidia:La_cabane',
        commons: 'https://commons.wikimedia.org',
        da: 'https://fr.vikidia.org/wiki/VD:DA',
        db: 'https://fr.vikidia.org/wiki/VD:DB',
        plagium: 'http://www.plagium.com/detecteurdeplagiat.cfm',
        savant: 'https://fr.vikidia.org/wiki/Vikidia:Le_Savant',
        tickets: 'https://fr.vikidia.org/wiki/Vikidia:Tickets',
        version: "VikiLinkBot-rb #{self.class.version}",

        # Lambdas for customization

        info: lambda do |q, _|
          domain, query = q.size == 1 ? [nil, q.first] : q
          query = query.downcase.split('/').map(&:strip)
          return "Désolé, je ne peux rien faire d'une requête vide !" if query.empty?
          prop = query.first.to_sym

          aliases = {
              pages: %w(statistics pages),
              articles: %w(statistics articles),
              edits: %w(statistics edits),
              fichiers: %w(statistics images),
              utilisateurs: %w(statistics users),
              actifs: %w(statistics activeusers),
              admins: %w(statistics admins),
              jobs: %w(statistics jobs),
          }
          if aliases.key? prop
            query.shift
            query.unshift *aliases[prop]
          end

          wiki = wikis.get(domain)
          answer = wiki.api action: 'query', meta: 'siteinfo', siprop: query.first
          unless answer['query']
            return "Désolé ! Soit la propriété #{query.first} n'existe pas, soit #{wiki.domain} refuse de partager." +
                " Essayez plutôt #{wiki.article_url('Special:Version')} !"
          end

          data = answer['query']
          parent_field = '(début)'
          query.each do |field|
            if data.is_a? Hash
              return "Désolé, pas de champ #{field} sous #{parent_field}, mais j'ai trouvé #{data.keys.join(', ')}" unless data.key? field
              data = data[field]
            else
              return "Désolé, pas de champ #{field} sous #{parent_field} = #{data}"
            end
            parent_field = field
          end
          if data.is_a? Hash
            "Désolé, #{parent_field} est un dictionnaire. Champs possibles : #{data.keys.join(', ')}"
          else
            "#{query.join('/')} (#{wiki.domain}) = #{data}"
          end
        end,

        contribs: lambda do |q, _|
          domain, username = q.size == 1 ? [nil, q.first] : [q.first, q.drop(1).join('_')]
          wiki = wikis.get(domain)

          if username =~ / \d{1,3} (?: \.\d{1,3} ){3} /x  # IPv4
            editcount = '?'
          else
            json = wiki.api(action: 'query', list: 'users', ususers: username, usprop: 'editcount')
            editcount = begin
              json['query']['users'][0]['editcount'] || raise
            rescue
              return "#{username} n'existe pas sur #{wiki.domain}"
            end
          end

          "#{editcount} - #{wiki.article_url('Special:Contributions/' + username)}"
        end,

        ip: lambda do |q, _|
          return 'Pour quelle adresse ?' if q.empty?
          return "Désolé, #{q.first} n'est pas une adresse IPv4." unless q.first =~ /^ \d{1,3} (?: \. \d{1,3} ){3} $/x
          url = 'https://whatismyipaddress.com/ip/' + q.first
          begin
            @httpc.get_content(url) do |chunk|
              chunk.scan /<meta name="description" content="([^"]+)"/ do |capture, _|
                return capture.gsub!(/^Location:\s+|\s+Learn more\.$/, '') ? "#{capture} - #{url}" : url
              end
            end
          rescue
            "Désolé, erreur ou absence de réponse du côté de #{url}."
          end
        end,

        si: lambda do |q, _|
          wiki = wikis.get('fr.vikidia.org')
          answer = wiki.api action: 'query', prop: 'categoryinfo', indexpageids: 1,
                                                   titles: 'Catégorie:Suppression_immédiate'
          category_size = answer['query']['pages'][answer['query']['pageids'][0]]['categoryinfo']['size']
          url = wiki.article_url('Catégorie:Suppression_immédiate')
          "À supprimer : #{category_size} - #{url}"
        end,

        vote: lambda do |q, _|
          return 'Il me faut un type de vote et une cible !' if q.size < 2
          kind, target = q.first.downcase.to_sym, q.drop(1).join('_')
          kinds = {
              admin: 'Vikidia:Administrateur',
              bureaucrate: 'Vikidia:Bureaucrate',
              contestation: "Vikidia:Contestation_du_statut_d'administrateur",
              pdd: 'Vikidia:Prise_de_décision',
              sa: 'Vikidia:Super_article/Élection'
          }
          unless kinds.key? kind
            guesses = guess(kind.to_s, kinds.keys)
            if guesses.size == 1
              kind = guesses.first.to_sym
            else
              return guesses.empty? ?
                  "Désolé, je ne connais pas #{kind} mais #{kinds.keys.join(', ')}." :
                  "Je ne connais pas #{kind}, vouliez-vous plutôt dire #{join_multiple(guesses)} ?"
            end
          end

          wiki = wikis.get('fr.vikidia.org')
          title = "#{kinds[kind]}/#{target}"
          content = wiki.api action: 'query', prop: 'revisions', titles: title, indexpageids: 1, rvlimit: 1, rvprop: 'content'
          begin
            content = content['query']['pages'][content['query']['pageids'][0]]['revisions'][0]['*']
          rescue NoMethodError
            return "Ce vote n'a pas l'air d'exister. Pour le créer : #{wiki.article_url(title)}"
          end
          votes = Hash.new(0)
          section = nil
          content.each_line do |line|
            case line.downcase
              when /\A(?>=+\s*)(?!\{\{|pour|contre|neutre)/
                section = nil
              when /\A(?>=+\s*)(?:\{\{)?(pour|contre|neutre)/
                section = $1
              when /\A(?>#\s*)\{\{(pour|contre|neutre)\b/
                votes[$1] += 1 if section
              when /\A(?>#\s*)\w/
                votes[section] += 1 if section
            end
          end
          comment = (votes.values.reduce(0, &:+) == 0) ?
              "Personne n'a encore voté" :
              votes.map { |k, v| "#{v} #{k}" }.join(', ') +
                  " (#{(100 * votes['pour'] / votes.values.reduce(0, &:+).to_f).round(2)} % d'accord)"
          "#{comment} - #{wiki.article_url(title)}"
        end,

        wikiscan: lambda do |q, _|
          username = q.join('_')
          return 'Pour quel utilisateur ?' if username.empty?
          url = 'http://wikiscan.org/utilisateur/' + username
          begin
            @httpc.get_content(url) do |chunk|
              chunk.scan /title="([^"]+)" alt="répartition/ do |capture, _|
                return "#{capture} - #{url}"
              end
            end
          rescue
            "Désolé, erreur ou absence de réponse du côté de #{url}."
          end
        end
    }
  end

  match /\w+/, strip_colors: true, use_prefix: false

  # @param [String] input
  # @param [Array<String>] possibilities
  # @return [Array<String>]
  def guess(input, possibilities)
    # Start guessing using abbreviations
    guesses = possibilities.abbrev(input).values.uniq
    return guesses if guesses.size == 1

    # If no abbreviation is satisfying, try Levenshtein
    guesses = possibilities.map { |p| [p, DamerauLevenshtein.distance(input, p.to_s, 1, 4)] }
                  .select { |_, d| d < 5 && d <= 2 * input.size / 3.0 }
                  .sort_by { |_, d| d }

    guesses.take_while { |_, d| d <= guesses.first.last } # consider only the best ones
        .map { |p, _| p } # loose the array, we don't care about the distance anymore
  end

  # @param [Array<String>] possibilities
  # @return [String]
  def join_multiple(possibilities, intermediate=', ', final=' ou ')
    possibilities.size > 1 ?
        [possibilities[0..-2].join(intermediate), possibilities.last].join(final) :
        possibilities.first
  end

  def execute(m)
    execute_command(m)
    execute_wikilinks(m)
  end

  def execute_command(m)
    return unless m.message.start_with? self.class.cmd_prefix
    cmd, *rest = m.message.split
    cmd.sub!('!', '')
    recipe = @commands[cmd.to_sym]
    answer = case recipe
               when String # just return the string
                 recipe
               when Proc # returns the proc's result
                 recipe.call(rest, m)
               when nil # tries to guess what existing command was targeted
                 guesses = guess(cmd, @commands.keys).map { |g| self.class.cmd_prefix + g }
                 guesses.empty? ? nil : "Vouliez-vous dire #{join_multiple guesses} ?"
               else
                 raise "got unexpected recipe type #{recipe.class} for command #{cmd}"
             end
    m.reply answer if answer
  end

  def execute_wikilinks(m)
    wikilinks = wikilinks_in m.message
    update_wikilink_states(wikilinks)
    m.reply wikilinks.join(' · ')
  end

  def wikilinks_in(str)
    links = {}
    str.scan /\[\[  ( [^\[\]\|]+ )  (?: \| [^\]]* )?  \]\]/x do |pagename, _|
      pagename.strip!

      # A ":" prefix means that we don't want to check whether the page exists.
      check = true
      pagename.sub!(/^:+\s*/) { check = false; '' }

      # A "something:" prefix specifies where to look for the page.
      wiki = pagename.sub!(/^([a-z.]+):+\s*/, '') ? wikis.get($1) : wikis.get('fr.vikidia.org')

      hash = [wiki, pagename]
      if links[hash]
        links[hash] = Wikilink.new(wiki, pagename, check) if !links[hash].check && check
      else
        links[hash] = Wikilink.new(wiki, pagename, check)
      end

    end
    links.values
  end

  def update_wikilink_states(links)
    wikis = {}
    links.each { |link| (wikis[link.wiki] ||= []) << link if link.check }  # Builds a {wiki => [links]} map
    wikis.each do |wiki, link_list|
      states = wiki.page_states(*link_list.map(&:pagename))
      link_list.each { |link| link.state = states[link.pagename] }
    end
  end

end
