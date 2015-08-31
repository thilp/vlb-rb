require 'vlb/utils'

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
      @whitelist[channel.name] ? @whitelist[channel.name].each_pair : []
    end

    def self.auth?(user, _channel)
      user.authed?
    end

    def self.op?(user, channel)
      on_chan?(user, channel) && channel.users[user].include?('o')
    end

    def self.voiced?(user, channel)
      on_chan?(user, channel) && channel.users[user].include?('v')
    end

    def self.on_chan?(user, channel)
      channel && channel.users[user]
    end

    def self.whitelisted?(user, channel)
      if channel.nil?  # private message
        # Consider user whitelisted iff it is whitelisted on at least a chan
        return @whitelist.values.any? { |chan| chan[user.name] && user.host == chan[user.name][:host] }
      end

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

    @levels = {whitelisted?:1, auth?:2, on_chan?:4, voiced?:14, op?:31}

    def self.user_status(user, channel)
      status = 0
      @levels.sort_by { |_,v| -v }.each do |name, val|
        next if status & val > 0
        status |= send(name, user, channel) ? val : 0
      end
      status
    end

    def self.ok_with_one_of?(m, *checks)
      user_status = user_status(m.user, m.channel)
      checks = [checks] if checks.all? { |e| e.is_a?(Symbol) }
      checks.any? do |c|
        level = c.map { |e| @levels[e] }.reduce(0, :+)
        level & user_status == level
      end
    end

    def self.reject?(m, *checks)
      checks = [checks] if checks.all? { |e| e.is_a?(Symbol) }

      return false if ok_with_one_of?(m, *checks)

      expected = Utils.join_multiple(checks.map { |c| c.map(&:to_s).join('+') })
      m.reply "Désolé, vous n'avez pas le niveau de privilèges requis (#{expected})"
      true
    end

  end
end