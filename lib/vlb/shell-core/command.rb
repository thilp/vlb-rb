require 'vlb/trust/SEvlb'
require 'vlb/shell-core/input'

module VikiLinkBot::Shell

  class Command
    include Trust::ProtectedResource

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

    # @param [Cinch::Message] m
    # @param [VikiLinkBot::Shell::Input] input
    # @return [nil] this method's return value is discarded
    # @note Do not call this method directly. Use Command#run instead.
    # @raise [NotImplementedError] must be implemented in subclasses
    def body(m, input)
      raise NotImplementedError.new
    end
    private :body
  end

end
