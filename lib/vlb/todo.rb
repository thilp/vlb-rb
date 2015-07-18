require 'cinch'

module VikiLinkBot
  class Todo
    include Cinch::Plugin

    match //, react_on: :channel, use_prefix: false, strip_colors: true

    def execute(m)
      return unless m.message.start_with?(config[:nick])
      self.class.todos << {
          author: m.user.name,
          authed: m.user.authed?,
          date: Time.now,
          channel: m.channel.name,
          message: m.message.sub(%r< ^ #{config[:nick]} \W* TODO \W* >xi, '')
      }
      m.reply 'todo enregistré !'
    end

    class << self
      attr_accessor :todos
    end
  end
end