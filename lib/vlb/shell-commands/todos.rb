require 'vlb/trust_authority'

module VikiLinkBot
  class Shell

    def todo(m, input)
      return if VikiLinkBot::TrustAuthority.reject?(m, :auth?)
      (@todos ||= []) << {
          author: m.user.name,
          authed: m.user.authed?,
          date: Time.now,
          channel: m.channel ? m.channel.name : '(privmsg)',
          message: input.raw.gsub(/^!#{__method__}\s*/, '')
      }
      m.reply 'todo enregistré !'
    end

    def todos(m, _)
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)

      @todos ||= []

      if @todos.empty?
        m.reply '∅'
      else
        @todos.each_with_index do |h, i|
          m.reply "#{i}) " +
                      Format(:grey, h[:date].to_s) + ' ' + Format(:blue, h[:author]) +
                      ' (' + h[:channel] + ') : ' + h[:message]
          sleep 0.6
        end
      end
    end

    def untodo(m, input)
      return if VikiLinkBot::TrustAuthority.reject?(m, :whitelisted?)
      @todos ||= []
      indices = input.args.select { |e| e =~ /^\d+$/ }.map(&:to_i).sort
      deleted = 0
      indices.reverse_each { |i| deleted += 1 if @todos.delete_at(i) }
      s = deleted > 1 ? 's' : ''
      m.reply "#{deleted} todo#{s} supprimé#{s}"
    end

  end
end