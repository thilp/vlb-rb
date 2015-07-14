require 'singleton'

module VikiLinkBot
  class TrustAuthority
    include Singleton

    def initialize
      @whitelist = {}
    end

    def trust_user(user, channel)
      (@whitelist[channel.name] ||= []) << user.name
    end

    def untrust_user(user, channel=nil)
      if channel.nil?
        @whitelist.values.each { |v| v.delete(user.name) }
      else
        @whitelist[channel.name].delete(user.name)
      end
    end

    def whitelisted?(user, channel, *required_flags)
      return true if channel.users[user] && channel.users[user].include?('o')  # ops are always whitelisted
      return false unless @whitelist[channel.name] && @whitelist[channel.name].include?(user.name) && user.authed?

      user_flags = channel.users[user]
      return false if user_flags.nil?

      required_flags.all? do |rf|
        user_flags.include?(rf)
      end
    end

  end
end