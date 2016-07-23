require 'yaml'
require 'vlb/vlinq'

module VikiLinkBot
  class YamlFileStorage

    def initialize(filename=nil, name_separator='.')
      @filename = filename
      @stored = filename.nil? ? {} : YAML.load(File.read(filename)) || {}
      @name_sep = name_separator
      @write_lock = Mutex.new
    end

    def get(query, fallback=nil)
      begin
        VikiLinkBot::VLINQ.select(query, @stored, separator: @name_sep)
      rescue
        fallback
      end
    end

    def set(query, value, create=true)
      @write_lock.synchronize do
        VikiLinkBot::VLINQ.update(
          query, value, @stored,
          create: create,
          separator: @name_sep)
      end
    end

    def write(filename=@filename)
      return if filename.nil?
      @write_lock.synchronize do
        f = File.open(filename, 'w')
        f.puts(YAML.dump(@stored))
        f.close
      end
    end

  end
end
