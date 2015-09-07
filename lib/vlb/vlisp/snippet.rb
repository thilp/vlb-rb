module VikiLinkBot
  module VLisp

    # A piece of VLisp code.
    # This class provides facilities for execution and (de)serialization of VLisp programs.
    #
    # @since 2.4.1
    class Snippet

      # @param [String] source the VLisp source of the program this object is supposed to represent
      # @option options [TrueClass,FalseClass] check_anticipated (false) whether to check for errors corresponding to
      #   a valid VLisp expression yielding potentially unwanted results
      # @option options [TrueClass,FalseClass] enclose_with_and (false) whether to wrap the provided _input_ into an
      #   +(AND ...)+ expression, allowing to provide more than one VLisp expression in _input_
      # @note This method may raise various exceptions; please refer to {VikiLinkBot::VLisp.lisp2ruby}
      #   for more information about them.
      def initialize(source, options={})
        options = {enclose_with_and: true, check_anticipated: true}.merge(options)
        @source = source
        @parsed = lisp2ruby(source, options)
      end

      attr_reader :source, :parsed

      # Evaluates the predicate represented by this snippet.
      #
      # @param [Hash] _json a dictionary providing values for jsonrefs (possibly) embedded in this snippet
      # @return [TrueClass,FalseClass]
      def satisfied?(_json={})
        eval(@parsed)
      end

    end

  end
end