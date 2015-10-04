require 'vlb/wiki'
require 'vlb/utils'

module VikiLinkBot::Shell
  class Input
    include Enumerable

    attr_reader :raw

    def self.split(str)
      tokens = str.scan %r{ [^\s"\{\}]* (?> \{ [^"\}]* \} [^\s"\{\}]* )+  # something with brace expansion (but not quoted)
        | (?!< \S ) @[A-Za-z0-9][\w\.-]* (?!<[-])  # wiki argument
        | " (?> [^"\\]+ | \\. )* "  # quoted string
        | \S+  # anything else between blanks
      }x
      tokens.map! do |t|  # apply brace expansion
        if t =~ /^"/ # quoted strings
          t[1..-2]  # remove the now useless quotes, but do not apply brace expansion
        else
          Utils.expand_braces(t).split
        end
      end
      tokens.flatten
    end

    def initialize(str)
      @raw = str.taint
      @tokens = self.class.split(str)
    end

    def each
      if block_given?
        @tokens.each { |t| yield(t) }
      else
        @tokens.each
      end
    end

    # @return [Symbol]
    def command
      @command ||= @tokens.first[1..-1].to_sym
    end

    # @return [Enumerable<String>]
    def args
      @args ||= @tokens.drop(1).reject { |e| e.empty? || e.start_with?('@') }
    end

    # @return [Enumerable<Wiki>]
    def wikis
      @wikis ||= begin
        wf = WikiFactory.instance
        wikis = @tokens.drop(1).select { |e| e.start_with?('@') }.map { |e| wf.get(e[1..-1]) }
        wikis = [wf.get] if wikis.empty?
        wikis
      end
    end

    # @return [TrueClass,FalseClass]
    def empty?
      @tokens.empty?
    end
  end
end
