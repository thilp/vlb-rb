require 'vlb/vlisp/utils'

module VikiLinkBot
  module VLisp

    class ReadError < VLispError; end
    class UnexpectedEOFError < ReadError; end
    class UnexpectedClosingBraceError < ReadError; end
    class UnexpectedSemicolonError < ReadError; end
    class ExcessTokenError < ReadError; end
    class UnrecognizedTokenError < ReadError
      def initialize(text)
        @text = text
      end
      def message
        "‹#{@text}›"
      end
    end

    # Enumerates all tokens in the input string.
    #
    # @note This function does not manage expression nesting, it simply returns a flat array with no interpretation.
    #
    # @param [String] input string containing a VLisp expression
    # @return [Array<Token>] an array whose elements are the tokens extracted from _input_, in the same order
    #
    # @raise [UnrecognizedTokenError] if _input_ contains a token this method does not recognize
    def self.tokenize(input)
      tokens = []
      until input.empty?
        type, _ = @lexers.find { |_, regex| /\A#{regex}/.match(input) }
        if type
          matched = Regexp.last_match.to_s
          tokens << Token.new(type, matched) if type != :ignored
          input = input[matched.size..-1]
        else
          unrecognized = /\A\S+/.match(input)
          raise UnrecognizedTokenError.new(unrecognized.to_s)
        end
      end
      tokens
    end

    # Organize the provided token stream into a VLisp expression.
    #
    # @param [Array<Token>] tokens a token stream, as generated by {::tokenize}
    # @return [Token, Array<Token,Array>] a token stream similar to _tokens_, but with everything between braces
    #   (including the braces) replaced with a nested array, recursively
    #
    # @raise [UnexpectedEOFError] if the token stream ends before the end of the VLisp expression
    # @raise [UnexpectedClosingBraceError] if a closing brace is read where it should not
    # @raise [ExcessTokenError] if _strict_ is enabled and _tokens_ contains some tokens that are not part of the first VLisp expression
    def self.parse_expr(tokens, strict=false)
      raise UnexpectedEOFError.new if tokens.empty?
      t = tokens.shift
      res = case t.type

        # Some tokens can't be nor start an expression sequence.
        when :closing_brace
          raise UnexpectedClosingBraceError.new
        when :semicolon
          raise UnexpectedSemicolonError.new

        when :opening_brace
          parse_subexpr(tokens)

        # <jsonref> is a "normal" VLisp atom, so it should go in the else case,
        # but <jsonref>:<vlisp> is shortcut for (LIKE <jsonref> <vlisp>), so we deal with this "reader macro" here.
        when :jsonref
          if tokens.first && tokens.first.type == :semicolon
            tokens.shift # skip the semicolon
            begin
              rhs = parse_expr(tokens)
            rescue UnexpectedEOFError
              raise UnexpectedEOFError.new('missing RHS for JR:VL form')
            end
            if rhs.is_a?(Token) && (rhs.type == :jsonref || rhs.type == :identifier)
              rhs.instance_eval do  # you can omit quotes if there is no spaces in your rhs string
                @type = :string
                @text = '"' + @text + '"'
              end
            end
            [Token.new(:identifier, 'LIKE'), t, rhs]
          else
            t
          end

        else
          t # in any other case, the VLisp expression is simply the first token
      end
      raise ExcessTokenError.new(tokens.first) if strict && !tokens.empty?
      res
    end

    # Utility method for {::parse_expr} that deals with brace contents.
    #
    # @api private
    #
    # @param [Array<Token>] tokens
    # @return [Array<Token,Array>]
    def self.parse_subexpr(tokens)
      raise UnexpectedEOFError.new if tokens.empty?
      parsed = []
      while (t = tokens.shift)
        case t.type
          when :closing_brace
            return parsed
          when :opening_brace
            parsed << parse_subexpr(tokens)
          else
            parsed << t
        end
      end
      raise UnexpectedEOFError.new  # we should have read a closing brace before exhausting tokens
    end

  end
end