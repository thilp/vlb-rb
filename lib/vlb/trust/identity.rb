module VikiLinkBot::Trust

  module IdentityProvider
    def vlb_identity
      raise NotImplementedError.new
    end
  end

end

require 'cinch/message'

class Cinch::Message
  include VikiLinkBot::Trust::IdentityProvider

  def vlb_identity
    "#{user.domain} #{channel ? channel.name : 'pm'}"
  end
end
