module VikiLinkBot
  class Shell

    {
        aide: 'https://github.com/thilp/vlb-rb',
        if rep2[3].lower() == ":!rc": 
                    IRC.send("PRIVMSG %s :%s\r\n" % (rep2[2], "RC : #vikidia-recentchanges .")) 
 
                if rep2[3].lower() == ":!mypage": 
                    IRC.send("PRIVMSG %s :%s\r\n" % (rep2[2], "https://fr.vikidia.org/wiki/Special:MyPage .")) 
 
                if rep2[3].lower() == ":!gazette": 
                    IRC.send("PRIVMSG %s :%s\r\n" % (rep2[2], "https://fr.vikidia.org/wiki/Vikidia:Gazette .")) 
 
                if rep2[3].lower() == ":!pàs": 
                    IRC.send("PRIVMSG %s :%s\r\n" % (rep2[2], "https://fr.vikidia.org/wiki/Vikidia:Pages_%C3%A0_supprimer .")) 
 
                if rep2[3].lower() == ":!block": 
                    IRC.send("PRIVMSG %s :%s\r\n" % (rep2[2], "Bloquer un utilisateur (administrateurs) : https://fr.vikidia.org/wiki/Sp%C3%A9cial:Bloquer .")) 
 
                if rep2[3].lower() == ":!accueil": 
                    IRC.send("PRIVMSG %s :%s\r\n" % (rep2[2], "https://fr.vikidia.org/wiki/Vikidia:Accueil .")) 
    }.each do |k, v|
      class_eval <<-RUBY
        def #{k}(m, *_)
          m.reply "#{v}"
        end
      RUBY
    end

  end
end
