require 'vlb/shell-core/command'

module VikiLinkBot::Shell

  COMMANDS[:die] = Command.new do |_, _|
    bot.quit('Received !die. Bye!')
  end

end