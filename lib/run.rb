$: << File.expand_path(__dir__ + '/../lib')

require 'cinch'
require 'optparse'
require 'vlb/shell-core'
require 'vlb/wikilink_resolver'
require 'vlb/watcher'

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
    c.plugins.plugins = [VikiLinkBot::Shell, VikiLinkBot::WikiLinkResolver, VikiLinkBot::Watcher]
  end
end

PLUGIN_SHELL = bot.plugins.find { |e| e.is_a?(VikiLinkBot::Shell) }
if PLUGIN_SHELL
  {
      'VD:DA / VD:DB' => 'title:/^Vikidia:Demandes aux (admin|bureaucrates)/ (NOT log_type:patrol)',
      'Blanchiment' => '(< length/new 20) (> (/ length/old length/new) 3.0)'
  }.each do |wname, wconstraints|
    bot.loggers.info "Registering !watch #{wname}: #{wconstraints}"
    PLUGIN_SHELL.watch_register(
        wname, '#vikidia-rc-json', Channel('#vikidia'),
        VikiLinkBot::Input.split(wconstraints),
        '[[' + Cinch::Formatting.format(:blue, '${title}') + ']] par ' +
            Cinch::Formatting.format(:green, '${user}') + ' : « ${comment} »')
  end
end

bot.start