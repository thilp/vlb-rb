require 'vlb/trust/SEvlb'
require 'vlb/shell-core/input'

module VikiLinkBot::Shell

  COMMANDS = {}

  class Command
    include Trust::ProtectedResource

    def initialize(*mixins, &body)
      mixins.each(&:extend)
      define_singleton_method(body_name, &body)
    end

    # @param [Cinch::Message] m
    # @return [TrueClass,FalseClass] whether no error was caught during execution
    def run(m)
      check_access_by(Subject.get(m))
      parsed_input = VikiLinkBot::Shell::Input.new(m.message)
      begin
        body(m, parsed_input)
        true
      rescue => e
        m.reply "Exception rattrapée : #{e}"
        false
      end
    end

    private

    def body_name
      :body
    end

    # @param [Cinch::Message] m
    # @param [VikiLinkBot::Shell::Input] input
    # @return [nil] this method's return value is discarded
    # @note Do not call this method directly. Use Command#run instead.
    def body(m, input)
      # Do nothing
    end
  end

end
