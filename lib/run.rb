$: << File.expand_path(__dir__ + '/../lib')

require 'cinch'
require 'vlb'
require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  opts.on('-s SERVER', 'IRC server') { |server| options[:server] = server }
  opts.on('-c CHAN', 'IRC channel') { |chan| (options[:chans] ||= []) << chan }
  opts.on('-n NICK', 'nickname') { |nick| options[:nick] = nick }
  opts.on('-p PWD', 'password') { |pwd| options[:pwd] = pwd }
end.parse!

if [:server, :chans, :nick].any? { |o| !options[o]}
  puts 'Missing option!'
  exit 1
end

bot = Cinch::Bot.new do
  configure do |c|
    c.nick = options[:nick]
    c.password = options[:password] if options[:password]
    c.server = options[:server]
    c.channels = options[:chans]
    c.plugins.plugins = [VikiLinkBot]
  end
end

bot.start