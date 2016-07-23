require 'vlb/status-checker'
require 'vlb/trust_authority'
require 'vlb/utils'

module VikiLinkBot
  class Shell
    def status(m, input)
      cls = VikiLinkBot::StatusChecker
      if input.args.first
        case input.args.first.downcase
        when 'ack'
          return if VikiLinkBot::TrustAuthority.reject?(m, :op?)
          res = VikiLinkBot::Utils.join_multiple(
              input.args.drop(1).select { |host| cls.ack_last_error(host) },
              ', ', ' et ')
          if res.nil?
            m.reply("Désolé, aucun de ces domaines n'a encore émis une erreur.")
          else
            m.reply("J'ignorerai désormais la dernière erreur rapportée pour #{res}.")
          end
        when 'unack'
          return if VikiLinkBot::TrustAuthority.reject?(m, :op?)
          res = VikiLinkBot::Utils.join_multiple(
            input.args.drop(1).select { |host| cls.unack(host) }, ', ', ' et ')
          if res.nil?
            m.reply("Désolé, aucun de ces domaines n'était ignoré.")
          else
            m.reply("D'accord, je n'ignore plus les erreurs de #{res}")
          end
        when 'acked'
          res = VikiLinkBot::Utils.join_multiple(
            cls.acked.map { |k,v| "#{k} (#{v})" }, ', ', ' et ')
          if res.nil?
            m.reply("Aucun domaine n'est actuellement ignoré.")
          else
            m.reply("Domaines actuellement ignorés : #{res}")
          end
        end
      else
        statuses = cls.find_errors
        cls.last_statuses = statuses
        m.reply("#{statuses}")
      end
    end
  end
end
