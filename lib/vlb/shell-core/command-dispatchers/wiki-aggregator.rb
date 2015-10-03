module VikiLinkBot::Shell
  module Dispatcher

    # Mix this module in {Command}s that simply loop over their arguments, repeating the same action for each of them, on
    # each specified wiki.
    module WikiAggregator

      # How many times (at most) {dispatched_body} may be run in {body}.
      MAX_DISPATCHES = 5

      # Runs {dispatched_body} once for each specified wiki, with the full argument list.
      #
      # For instance, if the "abc" command was defined using WikiAggregator, a call to:
      #
      #   !abc A A B @x @y @x C
      #
      # would lead to the corresponding {dispatched_body} method being executed in the following sequence:
      #
      #   dispatched_body(_, @x, [A, A, B, C])
      #   dispatched_body(_, @y, [A, A, B, C])
      #
      # except that there would be at most {MAX_DISPATCHES} such calls. If that limit is reached, an explanatory message
      # is issued and the command exits.
      #
      # @param [Cinch::Message] m
      # @param [VikiLinkBot::Shell::Input] input
      def body(m, input)
        wikis = input.wikis.uniq
        wikis.take(MAX_DISPATCHES).each do |wiki|
          dispatched_body(m, wiki, input.args)
        end
        m.reply("(désolé, limite de #{MAX_DISPATCHES} combinaisons atteinte)") if wikis.size >= MAX_DISPATCHES
      end

      # The command's logic for the specified `wiki` and `arg`.
      # Since it may be called multiple times in a row, it should not issue more than a one-line message.
      #
      # @param [Cinch::Message] m
      # @param [VikiLinkBot::Wiki] wiki
      # @param [Array<String>] args
      def dispatched_body(m, wiki, args)
        raise NotImplementedError.new
      end
      private :dispatched_body
    end
  end
end