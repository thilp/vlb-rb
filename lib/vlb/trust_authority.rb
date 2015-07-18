require 'singleton'

module VikiLinkBot
  class TrustAuthority

    @whitelist = {}

    def self.trust_user(user, channel, truster)
      @whitelist[channel.name] ||= {}
      @whitelist[channel.name][user.name] = {host: user.host, date: Time.now, truster: truster.name}
    end

    def self.untrust_user(user, channel=nil)
      chans = channel ? [@whitelist[channel.name]] : @whitelist.values
      chans.each do |chan_users|
        chan_users.delete(user.name)
      end
    end

    def self.trusted_users(channel)
      @whitelist[channel.name].each_pair
    end

    def self.op?(user, channel)
      channel.users[user] && channel.users[user].include?('o')
    end

    def self.has_flags?(user, channel, *required_flags)
      return true if required_flags.empty?

      user_flags = channel.users[user]
      return false if user_flags.nil?

      required_flags.all? do |f|
        user_flags.include?(f)
      end
    end

    def self.whitelisted?(user, channel)
      return false if @whitelist[channel.name].nil?

      metadata = @whitelist[channel.name][user.name]
      return false if metadata.nil?

      if user.authed?
        metadata[:host] = user.host  # update the host, so that the old one cannot be used anymore
        return true
      end

      if user.host == metadata[:host]
        return true
      else
        untrust_user(user)
      end
      false
    end

    def self.reject?(m, *checks)
      return false if op?(m.user, m.channel)

      return false if checks.include?(:whitelisted?) && whitelisted?(m.user, m.channel)

      flags = checks.select { |c| c.start_with?('+') }.map { |f| f[1..-1].chars }.flatten
      return false if !flags.empty? && has_flags?(m.user, m.channel, *flags)

      m.reply "Désolé, vous n'avez pas le niveau de privilèges requis."
      true
    end

  end
end