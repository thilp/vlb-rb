require 'yaml'
require 'vlb/vlinq'

module VikiLinkBot
  class YamlFileStorage

    def initialize(filename=nil, name_separator='.')
      @filename = filename
      @stored = filename.nil? ? {} : YAML.load(File.read(filename)) || {}
      @name_sep = name_separator
    end

    def get(query, fallback=nil)
      begin
        VikiLinkBot::VLINQ.select(query, @stored, separator: @name_sep)
      rescue
        fallback
      end
    end

    def set(query, value, create=true)
      VikiLinkBot::VLINQ.update(query, value, @stored, create: create, separator: @name_sep)
    end

    def write(filename=@filename)
      return if filename.nil?
      f = File.open(filename, 'w')
      f.puts(YAML.dump(@stored))
      f.close
    end

  end
end