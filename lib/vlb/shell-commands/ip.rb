module VikiLinkBot
  class Shell

    def ip(m, input)
      if input.args.empty?
        m.reply 'Pour quelles adresses ?'
        return
      end
      input.args.each do |ip|
        unless ip =~ /^ \d{1,3} (?: \. \d{1,3} ){3} $/x
          m.reply "Désolé, #{ip} n'est pas une adresse IPv4."
          next
        end

        url = 'https://whatismyipaddress.com/ip/' + ip

        begin
          @httpc.get_content(url) do |chunk|
            chunk.scan /<meta name="description" content="([^"]+)"/ do |capture, _|
              m.reply(capture.gsub!(/^Location:\s+|\s+Learn more\.$/, '') ? "#{capture} - #{url}" : url)
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