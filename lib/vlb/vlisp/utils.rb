require 'vlb/utils'

module VikiLinkBot
  module VLisp

    class Token
      attr_reader :type, :text
      def initialize(type, text)
        @type = type
        @text = text
      end
      def to_s
        "‹#{@text}›(#{@type})"
      end
      def ==(other)
        other.is_a?(VikiLinkBot::VLisp::Token) && @type == other.type && @text == other.text
      end
    end

    BOUNDARY = %r{ [\s()] | \Z }x

    @lexers = {
        ignored: %r{ \s+ }x,
        truth: %r{ \# [tf] (?=#{BOUNDARY}) }x,
        decimal: %r{ -* [0-9_]+ (?: \. [0-9_]+ )? (?=#{BOUNDARY}) }x,
        hexadecimal: %r{ -* 0x [0-9a-f_]+ (?=#{BOUNDARY}) }x,
        string: %r{ " (?> \\ . | [^\\"]+ )* " }x,
        regex: %r{ / ( (?> \\ . | [^\\/]+ )* ) / ( [A-Za-z]* ) (?=#{BOUNDARY}) }x,
        jsonref: %r{ [a-z_][a-z0-9_/-]* (?<! [-/] ) (?=:|#{BOUNDARY}) }x,
        opening_brace: %r{ \( }x,
        closing_brace: %r{ \) }x,
        semicolon: %r{ : }x,
        identifier: %r{ (?! [0-9] ) [^.\s"/]+ (?=#{BOUNDARY}) | [^\w\s"]+ (?=#{BOUNDARY}) }x,
    }

    class VLispError < VikiLinkBot::Utils::VLBError; end

    class TranslationError < VLispError; end
    class AnticipatedError < VLispError; end



    class AlwaysTrueError < AnticipatedError; end
    class AlwaysFalseError < AnticipatedError; end

  end
end

class Enumerator
  def empty?
    begin
      peek
    rescue

    end
  end
end