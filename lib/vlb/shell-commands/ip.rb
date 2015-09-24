module VikiLinkBot
  class Shell

    def ip(m, input)
      if input.args.empty?
        m.reply 'Pour quelles adresses ?'
        return
      end
      input.args.uniq.each do |ip|
        unless ip =~ /^ \d{1,3} (?: \. \d{1,3} ){3} $/x
          m.reply "Désolé, #{ip} n'est pas une adresse IPv4."
          next
        end

        begin
          h = @jsonc.get('http://ipinfo.io/' + ip, nil, 'User-Agent' => 'curl/7.0.1').content  # we have to cheat to get JSON instead of HTML ...
          m.reply "#{h['hostname']} (#{h['ip']}, #{h['org']}) : " +
                      "#{h['postal']} #{h['city']}, #{h['region']} (#{h['country']})" +
                      " - https://www.openstreetmap.org/#map=12/#{h['loc'].tr(',', '/')}"
        rescue  # try our old provider
          begin
            url = 'https://whatismyipaddress.com/ip/' + ip
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
end