module VikiLinkBot
  class Shell

    {
        aide: 'https://github.com/thilp/vlb-rb'
        rc: 'RC : #vikidia-recentchanges',
        mypage: 'https://fr.vikidia.org/wiki/Special:MyPage',
        gazette: 'https://fr.vikidia.org/wiki/Vikidia:Gazette',
        pas: 'https://fr.vikidia.org/wiki/Vikidia:Pages_%C3%A0_supprimer',
        block: 'Bloquer un utilisateur (administrateurs) : https://fr.vikidia.org/wiki/Sp%C3%A9cial:Bloquer',
        accueil: 'https://fr.vikidia.org',
        wikipedia: 'https://fr.wikipedia.org',
    }.each do |k, v|
      class_eval <<-RUBY
        def #{k}(m, *_)
          m.reply "#{v}"
        end
      RUBY
    end

  end
end
