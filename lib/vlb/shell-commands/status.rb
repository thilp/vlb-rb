require 'vlb/status-checker'

module VikiLinkBot
  class Shell
    def status(m, _input)
      statuses = VikiLinkBot::StatusChecker.find_errors
      m.reply(VikiLinkBot::StatusChecker.format_errors(statuses))
    end
  end
end