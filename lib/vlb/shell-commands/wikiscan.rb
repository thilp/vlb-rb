module VikiLinkBot
  class Shell

    def wikiscan(m, input)
      input.args.uniq.each do |username|
        if username.empty?
          m.reply 'Pour quel utilisateur ?'
          return
        end
        url = 'http://wikiscan.org/utilisateur/' + username
        begin
          @httpc.get_content(url) do |chunk|
            chunk.scan /title="([^"]+)" alt="répartition/ do |capture, _|
              m.reply "#{capture} - #{url}"
              next
            end
          end
        rescue
          m.reply "Désolé, erreur ou absence de réponse du côté de #{url}."
        end
      end
    end

  end
end