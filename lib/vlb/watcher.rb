require 'cinch'
require 'json'
require 'vlb/utils'

module VikiLinkBot

  class Watcher
    include Cinch::Plugin

    match //, use_prefix: false

    def initialize(*_)
      super
      @trusted_sources = {}
      @source_buffer = {}
    end

    def execute(m)
      # Ignore messages from non-watched channels
      return unless m.channel?
      return if self.class.registry.empty?
      chan_name = m.channel.name
      return unless self.class.trusted_sources.key?(chan_name)
      return unless self.class.trusted_sources[chan_name].include?(m.user.name)

      full_json = nil
      synchronize(:json) do
        # Careful, the message could be incomplete JSON
        buffer = @source_buffer[chan_name] || ''
        begin
          full_json = JSON.parse(buffer + m.message)
        rescue JSON::ParserError
          if m.message.start_with?('{')
            begin
              full_json = JSON.parse(m.message) # you never know ...
            rescue JSON::ParserError
              @source_buffer[chan_name] = m.message # replace the old buffer with m.message for the next chunk
              return
            end
          else
            @source_buffer[chan_name] = buffer + m.message # ok, seems this is going to span more than 2 chunks ...
            return
          end
        end
        @source_buffer[chan_name] = ''
      end
      full_json = VikiLinkBot::Utils.unescape_unicode_in_values(full_json)

      self.class.registry.values.each do |predicate, callback|
        if predicate.call(m, full_json) && callback
          callback.call(m, full_json)
        end
      end
    end

    @registry = {}
    class << self
      attr_reader :trusted_sources, :registry
    end

    def self.register(predicate, callback=nil)
      @counter ||= 0
      @counter += 1
      @registry[@counter] = [predicate, callback]
      @counter
    end

    def self.unregister(wid)
      if @registry.key?(wid)
        @registry.delete(wid)
        true
      else
        false
      end
    end

  end
end