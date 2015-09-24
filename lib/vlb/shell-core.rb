require 'cinch'
require 'httpclient'
require 'jsonclient'
require 'vlb/utils'
require 'vlb/wiki'

Dir.glob(__dir__ + '/shell-commands/*.rb').each do |fname|
  require fname
end

module VikiLinkBot

  class Input
    include Enumerable

    attr_reader :raw

    def self.split(str)
      tokens = str.scan %r{
        @[A-Za-z0-9\{][\w.-{,}]* (?!<[\{-]) |
        [A-Za-z/\{][^\s:()]* (?: : (?: (?!/) [^\s"()]+ |
                                       \#[tf] |
                                       /(?: [^/\\]+ | \\. )*/i? |
                                       "(?: [^"\\]+ | \\. )*" ) )? |
        \( | \) |
        "(?: [^"\\]+ | \\. )*" |
        (?: \S (?<! [()":] ) )+
      }x
      tokens.map! do |t|  # apply brace expansion, except on regexps!
        if t =~ %r{ ^ ([\w\{\},]+) ( : ["/] .+ ) $ }x
          Utils.expand_braces($1 + $2.tr('{} ', "\0\1\2")).tr("\0\1", '{}').split.map { |e| e.tr("\2", ' ') }
        elsif t =~ /^"/
          t[1..-2]  # remove the now useless quotes
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
      @args ||= @tokens.drop(1).reject { |e| e.empty? || e.start_with?('@') }
    end

    def wikis
      @wikis ||= begin
        wf = WikiFactory.instance
        wikis = @tokens.drop(1).select { |e| e.start_with?('@') }.map { |e| wf.get(e[1..-1]) }
        wikis = [wf.get] if wikis.empty?
        wikis
      end
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
      @jsonc = JSONClient.new
    end

    def self.ignore?(m)
      %w<78.225.229.37 Lucas0231>.any? { |x| m.user.host.include?(x) }
    end

    def read_eval(m, super_tokens=nil)
      input = super_tokens || Input.new(m.message)

      return if input.empty?

      return if self.class.ignore?(m)

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
      m.reply 'VikiLinkBot::Shell 2.4.2'
    end

  end

end
