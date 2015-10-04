module VikiLinkBot::Shell
  module Filter

    # Mix this in a {Command} to make it reject empty argument lists.
    module NonemptyArgs

      # @param [Cinch::Message] m
      # @param [VikiLinkBot::Shell::Input] input
      def body(m, input)
        if input.args.none?
          empty_args_action(m, input)
        else
          super
        end
      end

      # @param [Cinch::Message] m
      # @param [VikiLinkBot::Shell::Input] input
      def empty_args_action(m, input)
        m.reply 'Il me faut des arguments !'
      end

    end

  end
end