require 'vlb/vlinq'
require 'vlb/vlisp/reader'
require 'vlb/vlisp/translator'
require 'vlb/vlisp/utils'
require 'vlb/utils'

module VikiLinkBot

  # Implementation of (a subset of) a Scheme-like[https://en.wikipedia.org/wiki/Scheme_%28programming_language%29]
  # language, useful to express predicates for the +!watch+ command.
  # Methods in this module simply translate VLisp expressions to Ruby code, which can then be executed using +eval+.
  #
  # @since 2.4.0
  module VLisp

    class AnticipatedError < VLispError; end

    class AlwaysTrueError < AnticipatedError; end
    class AlwaysFalseError < AnticipatedError; end

    # Translates one or more VLisp expressions into Ruby code.
    #
    # This method is a wrapper around {::tokenize}, {::parse_expr} and {::translate_expr}.
    # It adds support for multiple expressions (with the +enclose_with_and+ option) and detects more errors
    # (with the +check_anticipated+ option).
    #
    # @return [String] Ruby code equivalent to the provided VLisp expressions
    # @param [String] input string containing one or more top-level VLisp expressions
    # @option options [TrueClass,FalseClass] check_anticipated (false) whether to check for errors corresponding to
    #   a valid VLisp expression yielding potentially unwanted results
    # @option options [TrueClass,FalseClass] enclose_with_and (false) whether to wrap the provided _input_ into an
    #   +(AND ...)+ expression, allowing to provide more than one VLisp expression in _input_
    #
    # @raise [AlwaysTrueError, AlwaysFalseError] if the final expression is always true/false and _check_anticipated_
    #   is true
    # @raise [ReadError,TranslationError] possibly raised by {::tokenize}, {::parse_expr} or {::translate_expr}
    def self.lisp2ruby(input, options={})
      options = {enclose_with_and: false, check_anticipated: false}.merge(options)

      input = '(AND ' + input + ')' if options[:enclose_with_and]

      res = translate_expr(parse_expr(tokenize(input)))

      if options[:check_anticipated]
        begin
          always = eval(res.gsub(%r{begin;?\s*|;?\s*rescue;false;end}, ''))
        rescue NameError
          res
        else
          raise (always ? AlwaysTrueError : AlwaysFalseError).new
        end
      else
        res
      end
    end

  end
end