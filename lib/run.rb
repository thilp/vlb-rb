LIBPATH = File.expand_path(__dir__ + '/../lib/')
MISCPATH = File.expand_path(__dir__ + '/../misc/')
$: << LIBPATH

require 'cinch'
require 'optparse'
require 'vlb/shell-core/shell'
require 'vlb/wikilink_resolver'
require 'vlb/watcher'
require 'vlb/status-checker'

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

module VikiLinkBot
  class Watcher
    @trusted_sources = {
        '#vikidia-rc-json' => ['[Bifrost]']
    }
  end
end

bot = Cinch::Bot.new do
  configure do |c|
    c.nick = options[:nick]
    c.user = 'vlb-rb'
    c.realname = 'vlb-rb'
    c.password = options[:password] if options[:password]
    c.server = options[:server]
    c.channels = options[:chans] + VikiLinkBot::Watcher.trusted_sources.keys
    c.plugins.plugins = [VikiLinkBot::Shell::Shell, VikiLinkBot::WikiLinkResolver,
                         VikiLinkBot::Watcher, VikiLinkBot::StatusChecker]
  end
end

bot.start