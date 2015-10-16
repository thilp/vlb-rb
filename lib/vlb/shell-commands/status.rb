require 'vlb/status-checker'
require 'vlb/trust_authority'
require 'vlb/utils'

module VikiLinkBot
  class Shell
    def status(m, input)
      if input.args.first.downcase == 'ack'
        return if VikiLinkBot::TrustAuthority.reject?(m, :op?)
        res = VikiLinkBot::Utils.join_multiple(
            input.args.drop(1).select { |host| VikiLinkBot::StatusChecker.ack_last_error(host) },
            ', ', ' et ')
        m.reply("J'ignorerai la dernière erreur rapportée pour #{res} jusqu'à ce qu'elle disparaisse.")
      else
        statuses = VikiLinkBot::StatusChecker.find_errors
        m.reply(VikiLinkBot::StatusChecker.format_errors(statuses))
      end
    end
  end
end
