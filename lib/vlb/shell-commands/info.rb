module VikiLinkBot
  class Shell

    def info(m, input)
      domain, query = input.args.size == 1 ? [nil, input.args.first] : input.args
      query = query.downcase.split('/').map(&:strip)
      if query.empty?
        m.reply "Désolé, je ne peux rien faire d'une requête vide !"
        return
      end
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

      wiki = WikiFactory.instance.get(domain)
      answer = wiki.api action: 'query', meta: 'siteinfo', siprop: query.first
      unless answer['query']
        m.reply 'Désolé ! ' + case answer['warnings']['siteinfo']['*']
                               when "The ``siteinfo'' module has been disabled."
                                 "#{wiki.domain} ne rend pas ces informations publiques. Essayez plutôt #{wiki.article_url('Special:Version')}"
                               when /^Unrecognized value for parameter 'siprop': (.+)$/
                                 "La propriété #{query.first} n'existe pas. Les propriétés connues sont listées sur http://www.mediawiki.org/wiki/API:Siteinfo"
                               else
                                 "La requête a échoué, MediaWiki a répondu : #{answer['warnings']['siteinfo']['*']}"
                              end
        return
      end

      data = answer['query']
      parent_field = '(début)'
      query.each do |field|
        if data.is_a? Hash
          unless data.key?(field)
            m.reply "Désolé, pas de champ #{field} sous #{parent_field}, mais j'ai trouvé #{data.keys.join(', ')}"
            return
          end
          data = data[field]
        else
          m.reply "Désolé, pas de champ #{field} sous #{parent_field} = #{data}"
          return
        end
        parent_field = field
      end
      m.reply(data.is_a?(Hash) ?
                  "Désolé, #{parent_field} est un dictionnaire. Champs possibles : #{data.keys.join(', ')}" :
                  "#{query.join('/')} (#{wiki.domain}) = #{data}")
    end

  end
end