require 'cinch'
require 'vlb/trust_authority'
require 'vlb/utils'

module VikiLinkBot
  class Shell

    # These are defined in Object and clash with our own
    undef_method(:trust)
    undef_method(:untrust)

    def trust(m, tokens)
      unless m.channel.opped?(m.user)
        m.reply 'Désolé, seuls les opérateurs du canal peuvent utiliser cette commande.'
        return
      end
      trusted = []
      tokens.each do |username|
        user = User(username)
        unless user.authed?
          m.reply "L'utilisateur #{username} n'est pas authentifié (ignoré)."
          next
        end
        VikiLinkBot::TrustAuthority.instance.trust_user(user, m.channel)
        trusted << user.name
      end
      unless trusted.empty?
        m.reply "#{Utils.join_multiple(trusted, ', ', ' et ')} peuvent désormais utiliser les commandes à accès restreint."
      end
    end

    def untrust(m, tokens)
      unless m.channel.opped?(m.user)
        m.reply 'Désolé, seuls les opérateurs du canal peuvent utiliser cette commande.'
        return
      end
      untrusted = []
      tokens.each do |username|
        user = User(username)
        if m.channel.opped?(user)
          m.reply "L'utilisateur #{username} est opérateur (ignoré)."
          next
        end
        VikiLinkBot::TrustAuthority.instance.untrust_user(user)
        untrusted << user.name
      end
      unless untrusted.empty?
        m.reply "#{Utils.join_multiple(untrusted, ', ', ' et ')} ne peuvent plus utiliser les commandes à accès restreint."
      end
    end

  end
end