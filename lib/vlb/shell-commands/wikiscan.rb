module VikiLinkBot
  class Shell

    def wikiscan(m, tokens)
      username = tokens.join('_')
      if username.empty?
        m.reply 'Pour quel utilisateur ?'
        return
      end
      url = 'http://wikiscan.org/utilisateur/' + username
      begin
        @httpc.get_content(url) do |chunk|
          chunk.scan /title="([^"]+)" alt="répartition/ do |capture, _|
            m.reply "#{capture} - #{url}"
            return
          end
        end
      rescue
        m.reply "Désolé, erreur ou absence de réponse du côté de #{url}."
        return
      end
    end

  end
end