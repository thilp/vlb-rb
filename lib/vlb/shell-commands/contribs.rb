module VikiLinkBot
  class Shell

    def contribs(m, input)
      if input.args.empty?
        m.reply "Usage : !#{__method__} [<wiki>+] <pseudo>+"
        return
      end
      input.args.each do |username|
        input.wikis.each do |wiki|
          if username =~ / \d{1,3} (?: \.\d{1,3} ){3} /x # IPv4
            editcount = '?'
          else
            json = wiki.api(action: 'query', list: 'users', ususers: username, usprop: 'editcount')
            editcount = begin
              json['query']['users'][0]['editcount'] || raise
            rescue
              m.reply "#{username} n'existe pas sur #{wiki.domain}"
              return
            end
          end
          m.reply "#{editcount} - #{wiki.article_url('Special:Contributions/' + username)}"
        end
      end
    end

  end
end