require 'cinch'
require 'httpclient'
require 'vlb/shell-core/input'
require 'vlb/utils'

unless $DONT_LOAD_SHELL_COMMANDS
  Dir.glob(__dir__ + '/shell-commands/*.rb').each do |fname|
    require fname
  end
end

module VikiLinkBot::Shell

  class Shell
    include Cinch::Plugin

    match //, strip_colors: true, method: :read_eval

    def initialize(*_)
      super
      @httpc = HTTPClient.new
    end

    def read_eval(m, super_tokens=nil)
      input = super_tokens || Input.new(m.message)

      return if input.empty?

      if public_methods(false).include?(input.command)
        debug "Running command #{input.command} with arguments #{input.args} and wikis #{input.wikis.map(&:base_url)}"
        begin
          method(input.command).call(m, input)
        rescue => e
          m.reply "Oups ! Exception non rattrapée : #{e}"
          log(e.message + ' -- ' + e.backtrace.join("\n"))
        end
      else
        guesses = Utils.guess(input.command.to_s, public_methods(false)).map { |g| "!#{g}" }
        m.reply "Vouliez-vous dire #{Utils.join_multiple(guesses)} ?" unless guesses.empty?
      end

    end

    def version(m, tokens)
      m.reply 'VikiLinkBot::Shell 2.4.1 — « Songe à la douceur »'
    end

  end

end
