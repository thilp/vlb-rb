module VikiLinkBot
  class Shell

    def ip(m, tokens)
      if tokens.empty?
        m.reply 'Pour quelle adresse ?'
        return
      end
      unless tokens.first =~ /^ \d{1,3} (?: \. \d{1,3} ){3} $/x
        m.reply "Désolé, #{tokens.first} n'est pas une adresse IPv4."
        return
      end

      url = 'https://whatismyipaddress.com/ip/' + tokens.first

      begin
        @httpc.get_content(url) do |chunk|
          chunk.scan /<meta name="description" content="([^"]+)"/ do |capture, _|
            m.reply(capture.gsub!(/^Location:\s+|\s+Learn more\.$/, '') ? "#{capture} - #{url}" : url)
            return
          end
        end
      rescue
        return m.reply "Désolé, erreur ou absence de réponse du côté de #{url}."
      end
    end

  end
end