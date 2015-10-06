require 'vlb/utils'

module VikiLinkBot
  class Shell

    def info(m, input)
      if input.args.empty?
        m.reply 'Désolé, il me faut au moins une requête !'
        return
      end

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

      input.args.uniq.each do |query|
        query = query.downcase.split('/').map(&:strip)
        prop = query.first.to_sym

        if @aliases.key?(prop)
          query.shift
          query.unshift(*@aliases[prop])
        end

        input.wikis.uniq.each do |wiki|
          prefix = {
              good: "#{query.join('/')} (#{wiki.domain}) = ",
              bad: Format(:red, "#{query.join('/')} (#{wiki.domain}) : ")
          }
          answer = intercept(nil) { wiki.api action: 'query', meta: 'siteinfo', siprop: query.first }
          if answer.nil?
            m.reply "#{prefix[:bad]}impossible de contacter #{wiki.domain}"
            next
          elsif answer['query'].nil?
            case answer['warnings']['siteinfo']['*']
              when "The ``siteinfo'' module has been disabled."
                m.reply "#{prefix[:bad]}informations non publiques, essayez plutôt #{wiki.article_url('Special:Version')}"
              when /^Unrecognized value for parameter 'siprop': (.+)$/
                m.reply "#{prefix[:bad]}propriété inexistante. Les propriétés connues sont listées sur " +
                            'http://www.mediawiki.org/wiki/API:Siteinfo'
              else
                m.reply "#{prefix[:bad]}MediaWiki a répondu #{answer['warnings']['siteinfo']['*'].inspect}"
            end
            next
          end

          data = answer['query']
          parent_field = '(début)'
          begin
            query.each do |field|
              if data.is_a? Hash
                unless data.key?(field)
                  raise "pas de champ #{field} sous #{parent_field}, mais j'ai trouvé #{data.keys.join(', ')}"
                end
                data = data[field]
              else
                raise "pas de champ #{field} sous #{parent_field} = #{data}"
              end
              parent_field = field
            end
          rescue => s
            m.reply(prefix[:bad] + s.to_s)
            next
          end
          m.reply(data.is_a?(Hash) ?
                      "#{prefix[:bad] + parent_field} est un dictionnaire. Champs possibles : #{data.keys.join(', ')}" :
                      prefix[:good] + data.to_s)
        end
      end

    end
  end
end
