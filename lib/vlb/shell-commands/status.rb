require 'vlb/status-checker'
require 'vlb/trust_authority'
require 'vlb/utils'

module VikiLinkBot
  class Shell
    def status(m, input)
      cls = VikiLinkBot::StatusChecker
      if input.args.first && input.args.first.downcase == 'ack'
        return if VikiLinkBot::TrustAuthority.reject?(m, :op?)
        res = VikiLinkBot::Utils.join_multiple(
            input.args.drop(1).select { |host| cls.ack_last_error(host) },
            ', ', ' et ')
        m.reply("J'ignorerai la dernière erreur rapportée pour #{res} jusqu'à ce qu'elle disparaisse.")
      else
        statuses = cls.find_errors
        cls.last_statuses = statuses
        m.reply("État des sites : #{statuses}")
      end
    end
  end
end
