require 'vlb/shell-core/command'
require 'vlb/shell-core/command-filters/nonempty-args'
require 'vlb/shell-core/command-dispatchers/wiki-aggregator'
require 'vlb/vlinq'
require 'vlb/utils'

module VikiLinkBot::Shell

  COMMANDS[:info] = Command.new(Filter::NonemptyArgs, Dispatcher::WikiAggregator) do |m, wiki, args|
    @aliases ||= {
        pages: %w(statistics pages),
        articles: %w(statistics articles),
        edits: %w(statistics edits),
        fichiers: %w(statistics images),
        utilisateurs: %w(statistics users),
        actifs: %w(statistics activeusers),
        admins: %w(statistics admins),
        jobs: %w(statistics jobs),
    }

    root_queries = args.map { |arg| arg.downcase.split('/').map(&:strip) }.
                        map { |q| q.size == 1 ? @aliases.fetch(q.first.to_sym, q) : q }.
                        group_by(&:first)

    root_queries.each do |root_query, query_tails|

      bad_prefix = Format(:red, "#{wiki.domain} : ")
      answer = intercept(nil) { wiki.api action: 'query', meta: 'siteinfo', siprop: root_query }
      if answer.nil?
        m.reply "#{bad_prefix}impossible de contacter #{wiki.domain}"
      elsif answer['query'].nil?
        case answer['warnings']['siteinfo']['*']
          when "The ``siteinfo'' module has been disabled."
            m.reply "#{bad_prefix}informations non publiques, essayez plutôt #{wiki.article_url('Special:Version')}"
          when /^Unrecognized value for parameter 'siprop': (.+)$/
            m.reply "#{bad_prefix}propriété inexistante. Les propriétés connues sont listées sur " +
                        'http://www.mediawiki.org/wiki/API:Siteinfo'
          else
            m.reply "#{bad_prefix}MediaWiki a répondu #{answer['warnings']['siteinfo']['*'].inspect}"
        end
        next
      end

      query_tails.each do |query_tail|

        query = [root_query, *query_tail]
        good_prefix = "#{query.join('/')} (#{wiki.domain}) = "
        bad_prefix = Format(:red, "#{query.join('/')} (#{wiki.domain}) : ")

        begin
          data = VikiLinkBot::VLINQ.select(query, answer['query'], separator: '/', alternative_keys: true)
        rescue VikiLinkBot::VLINQ::VLINQError => e
          m.reply "#{prefix[:bad]}#{e.message}"
          next
        end
        m.reply(data.is_a?(Hash) ?
                    "#{bad_prefix}c'est un dictionnaire. Champs possibles : #{data.keys.join(', ')}" :
                    good_prefix + data.to_s)
      end
    end

  end

  COMMANDS[:info].define_singleton_method(:empty_args_action) do |m, _|
    m.reply 'Désolé, il me faut au moins une requête !'
  end

end