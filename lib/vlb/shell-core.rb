require 'cinch'
require 'shellwords'
require 'httpclient'
require 'vlb/utils'

Dir.glob(__dir__ + '/shell-commands/*.rb').each do |fname|
  require fname
end

module VikiLinkBot

  class Shell
    include Cinch::Plugin

    match //, strip_colors: true, method: :read_eval

    def initialize(*_)
      super
      @httpc = HTTPClient.new
    end

    def read_eval(m, super_tokens=nil)
      tokens = super_tokens || Utils.expand_braces(m.message).shellsplit

      return if tokens.empty?

      command = tokens.first[1..-1].to_sym
      if respond_to?(command)
        tokens.shift
        begin
          method(command).call(m, tokens)
        rescue => e
          m.reply "Oups ! Exception non rattrapée : #{e}"
          log(e.message + ' -- ' + e.backtrace.join("\n"))
        end
      else
        guesses = Utils.guess(command.to_s, methods).map { |g| "!#{g}" }
        m.reply "Vouliez-vous dire #{Utils.join_multiple(guesses)} ?" unless guesses.empty?
      end

    end

    def version(m, tokens)
      m.reply 'VikiLinkBot::Shell 2.1.0'
    end

  end

end