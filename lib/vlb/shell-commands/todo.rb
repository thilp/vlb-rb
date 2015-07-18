require 'vlb/todo'
require 'vlb/trust_authority'

module VikiLinkBot
  class Shell

    def todos(m, _)
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)

      if VikiLinkBot::Todo.todos.empty?
        m.reply '∅'
      else
        VikiLinkBot::Todo.todos.each do |h|
          m.reply "#{h[:date]} #{h[:author]}#{h[:authed] ? '*' : ''} (#{h[:channel]}) : #{h[:message]}"
          sleep 0.6
        end
      end
    end

  end
end