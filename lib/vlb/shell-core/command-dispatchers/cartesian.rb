module VikiLinkBot::Shell
  module Dispatcher

    # Mix this module in {Command}s that simply loop over their arguments, repeating the same action for each of them, on
    # each specified wiki.
    module CartesianProduct

      # How many times (at most) {dispatched_body} may be run in {body}.
      MAX_DISPATCHES = 5

      private

      # Runs {dispatched_body} for each provided combination of arguments and wikis.
      #
      # For instance, if the "abc" command was defined using CartesianProduct, a call to:
      #
      #   !abc A A B @x @y @x C
      #
      # would lead to the corresponding {dispatched_body} method being executed in the following sequence:
      #
      #   dispatched_body(_, @x, A)
      #   dispatched_body(_, @y, A)
      #   dispatched_body(_, @x, B)
      #   dispatched_body(_, @y, B)
      #   dispatched_body(_, @x, C)
      #   dispatched_body(_, @y, C)
      #
      # except that there would be at most {MAX_DISPATCHES} such calls. If that limit is reached, an explanatory message
      # is issued and the command exits.
      #
      # @param [Cinch::Message] m
      # @param [VikiLinkBot::Shell::Input] input
      def body(m, input)
        super
        dispatches = 0
        input.args.uniq.each do |wiki|
          input.wikis.uniq.each do |arg|
            if dispatches >= MAX_DISPATCHES
              m.reply("(désolé, limite de #{MAX_DISPATCHES} combinaisons atteinte)")
              return
            end
            dispatches += 1
            dispatched_body(m, wiki, arg)
          end
        end
      end

      def body_name
        :dispatched_body
      end

      # The command's logic for the specified `wiki` and `arg`.
      # Since it may be called multiple times in a row, it should not issue more than a one-line message.
      #
      # @param [Cinch::Message] m
      # @param [VikiLinkBot::Wiki] wiki
      # @param [String] arg
      def dispatched_body(m, wiki, arg)
        raise NotImplementedError.new
      end
    end
  end
end