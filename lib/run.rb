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

constraints = VikiLinkBot::Shell.watch_parse(VikiLinkBot::Input.split('title:/^Vikidia:Demandes aux (admin|bureaucrates)/'))
puts "Registering watcher from run.rb with constraints: #{constraints}"
VikiLinkBot::Watcher.register(
    lambda { |mm, _json| mm.channel.name == '#vikidia' && eval(constraints) },
    lambda do |_, _json|
      Channel('#vikidia').send '[watch] VD:DA / VD:DB'
      Channel('#vikidia').send "[watch] par #{_json['user']} sur #{_json['title']}#{
              (_json['comment'] && !_json['comment'].empty?) ? ' « ' + _json['comment'] + ' »' : '' }"
    end)

bot.start