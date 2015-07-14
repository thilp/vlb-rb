module VikiLinkBot
  class Shell

    def contribs(m, input)
      domain, usernames = input.args.size == 1 ?
          [nil, input.args.first] :
          input.args
      wiki = WikiFactory.instance.get(domain)

      usernames.each do |username|
        if username =~ / \d{1,3} (?: \.\d{1,3} ){3} /x # IPv4
          editcount = '?'
        else
          json = wiki.api(action: 'query', list: 'users', ususers: username, usprop: 'editcount')
          editcount = begin
            json['query']['users'][0]['editcount'] || raise
          rescue
            m.reply "#{username} n'existe pas sur #{wiki.domain}"
            next
          end
        end
        m.reply "#{editcount} - #{wiki.article_url('Special:Contributions/' + username)}"
      end

    end

  end
end