require 'cinch'
require 'httpclient'
require 'vlb/utils'

Dir.glob(__dir__ + '/shell-commands/*.rb').each do |fname|
  require fname
end

module VikiLinkBot

  class Input
    include Enumerable

    attr_reader :raw

    def self.split(str)
      tokens = str.scan %r{
        [A-Za-z/\{\}][\w/\{\},]* (?: : (?: \w+ | \#[tf] | /(?: [^/\\]+ | \\. )*/i? | "(?: [^"\\]+ | \\. )*" ) )? |
        \( | \) |
        "(?: [^"\\]+ | \\. )*" |
        (?: \S (?<! [()":] ) )+
      }x
      tokens.map! do |t|  # apply brace expansion, except on regexps!
        if t =~ %r{ ^ ([\w\{\},]+) ( : ["/] .+ ) $ }x
          Utils.expand_braces($1 + $2.tr('{} ', "\0\1\2")).tr("\0\1", '{}').split.map { |e| e.tr("\2", ' ') }
        elsif t =~ /^"/
          t[1..-1]  # remove the now useless quotes
        else
          Utils.expand_braces(t).split
        end
      end
      tokens.flatten
    end

    def initialize(str)
      @raw = str
      @tokens = self.class.split(str)
    end

    def each
      if block_given?
        @tokens.each { |t| yield(t) }
      else
        @tokens.each
      end
    end

    def command
      @command ||= @tokens.first[1..-1].to_sym
    end

    def args
      @tokens.drop(1)
    end

    def empty?
      @tokens.empty?
    end

  end

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

      if respond_to?(input.command)
        begin
          method(input.command).call(m, input)
        rescue => e
          m.reply "Oups ! Exception non rattrapée : #{e}"
          log(e.message + ' -- ' + e.backtrace.join("\n"))
        end
      else
        guesses = Utils.guess(input.command.to_s, methods).map { |g| "!#{g}" }
        m.reply "Vouliez-vous dire #{Utils.join_multiple(guesses)} ?" unless guesses.empty?
      end

    end

    def version(m, tokens)
      m.reply 'VikiLinkBot::Shell 2.2.1'
    end

  end

end