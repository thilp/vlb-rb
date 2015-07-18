require 'singleton'

module VikiLinkBot
  class TrustAuthority

    @whitelist = {}

    def self.trust_user(user, channel)
      (@whitelist[channel.name] ||= []) << user.name
    end

    def self.untrust_user(user, channel=nil)
      if channel.nil?
        @whitelist.values.each { |v| v.delete(user.name) }
      else
        @whitelist[channel.name].delete(user.name)
      end
    end

    def self.has_flags?(user, channel, *required_flags)
      return true if required_flags.empty?

      user_flags = channel.users[user]
      return false if user_flags.nil?

      required_flags.all? do |rf|
        user_flags.include?(rf)
      end
    end

    def self.whitelisted?(user, channel, *required_flags)
      return true if channel.users[user] && channel.users[user].include?('o')  # ops are always whitelisted
      return false unless @whitelist[channel.name] && @whitelist[channel.name].include?(user.name) && user.authed?
      has_flags?(user, channel, required_flags)
    end

    def self.reject?(m, f, *required_flags)
      if send(f, m.user, m.channel, *required_flags)
        true
      else
        m.reply "Désolé, vous n'avez pas le niveau de privilèges requis."
        false
      end
    end

  end
end