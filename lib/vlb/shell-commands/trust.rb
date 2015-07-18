require 'cinch'
require 'vlb/trust_authority'
require 'vlb/utils'

module VikiLinkBot
  class Shell

    # These are defined in Object and clash with our own
    undef_method(:trust)
    undef_method(:untrust)

    def trust(m, input)
      return if VikiLinkBot::TrustAuthority.reject?(m, '+o')
      trusted = []
      input.args.each do |username|
        user = User(username)
        unless user.authed?
          m.reply "#{username} n'est pas authentifié : confiance temporaire."
        end
        VikiLinkBot::TrustAuthority.trust_user(user, m.channel, m.user)
        trusted << user.name
      end
      unless trusted.empty?
        m.reply "#{Utils.join_multiple(trusted, ', ', ' et ')} peu#{trusted.size > 1 ? 'vent' : 't'} " +
                    'désormais utiliser les commandes à accès restreint.'
      end
    end

    def untrust(m, input)
      unless m.channel.opped?(m.user)
        m.reply 'Désolé, seuls les opérateurs du canal peuvent utiliser cette commande.'
        return
      end
      untrusted = []
      input.args.each do |username|
        user = User(username)
        if m.channel.opped?(user)
          m.reply "L'utilisateur #{username} est opérateur (ignoré)."
          next
        end
        VikiLinkBot::TrustAuthority.untrust_user(user)
        untrusted << user.name
      end
      unless untrusted.empty?
        m.reply "#{Utils.join_multiple(untrusted, ', ', ' et ')} ne peu#{trusted.size > 1 ? 'vent' : 't'} " +
                    'plus utiliser les commandes à accès restreint.'
      end
    end

    def trustme(m, _)
      if File.exist?("/tmp/#{m.user.name}")
        File.delete("/tmp/#{m.user.name}")
        VikiLinkBot::TrustAuthority.trust_user(m.user, m.channel, m.user)
        m.reply "D'accord !"
      else
        m.reply 'Petit malin ! Non.'
      end
    end

    def trusted(m, input)
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)
      VikiLinkBot::TrustAuthority.trusted_users(m.channel).each do |nick, metadata|
        next unless input.args.empty? || input.args.include?(nick)
        m.reply "#{nick}@#{metadata[:host]} par #{metadata[:truster]} (#{metadata[:date]})"
        sleep 1
      end
    end

  end
end