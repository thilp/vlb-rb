require 'vlb/trust_authority'

module VikiLinkBot
  class Shell

    def die(m, _)
      return if VikiLinkBot::TrustAuthority.reject?(m, :op?)
      bot.quit('Received !die. Bye!')
    end

  end
end