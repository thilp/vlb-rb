require 'vlb/utils'

class String
  def integer?
    begin
      Integer(self)
    rescue ArgumentError
      false
    else
      true
    end
  end
end

class Array
  def index_valid?(idx)
    begin
      fetch(idx)
    rescue IndexError
      false
    else
      true
    end
  end
end

module VikiLinkBot

  # The VLINQ module contains functions that *create*, *read*, *update* or *delete*
  # (CRUD[https://en.wikipedia.org/wiki/Create,_read,_update_and_delete]) data from *containers*, relieving
  # the developer from thinking about the exact container type and how to perform the specific operation on it.
  # {Hence the name}[https://en.wikipedia.org/wiki/Language_Integrated_Query].
  #
  # @since 2.4.0
  module VLINQ

    class VLINQError < VikiLinkBot::Utils::VLBError; end
    class UnsupportedContainerError < VLINQError
      attr_reader :type
      def initialize(type)
        @type = type
      end
      def message
        "don't know how to query a container of type #{@type}"
      end
    end
    class NotAnIndexError < VLINQError
      attr_reader :access
      def initialize(access)
        @access = access
      end
      def message
        "invalid index #{@access.inspect} for array access"
      end
    end
    class OutOfBoundsError < VLINQError
      attr_reader :access, :size
      def initialize(access, size)
        @access = access
        @size = size
      end
      def message
        "invalid index #{@access} in queried array of size #{@size}"
      end
    end
    class UnknownKeyError < VLINQError
      attr_reader :key
      def initialize(key)
        @key = key
      end
      def message
        "unknown key #{@key.inspect} in queried hash"
      end
    end

    # Returns the value corresponding to the specified query in the specified source.
    # The separator is used to break the query into path components that are interpreted,
    # depending on source's type, as indices (Array) or keys (Hash).
    #
    # @param [String] query a sequence of tokens (separated by separator) describing how to access the targeted value
    # @param [Object] source the (possibly nested) container in which to search for the targeted value
    # @option options [TrueClass,FalseClass] create (false) whether to create a queried but non-existent path
    # @option options [String] separator ('/') what stands between each query part
    def self.select(query, source, options={})
      options = {create: false, separator: '/'}.merge(options)
      key, ks = query.split(options[:separator], 2)
      case source
        when Array
          if key.integer?
            if options[:create] || source.index_valid?(key.to_i)
              ks.nil? ? source[key.to_i] : select(ks, source[key.to_i], options)
            else
              raise OutOfBoundsError.new(key.to_i, source.size)
            end
          else
            raise NotAnIndexError.new(key)
          end
        when Hash
          key = key.to_sym if !source.key?(key) && source.key?(key.to_sym)
          if options[:create] || source.key?(key)
            ks.nil? ? source[key] : select(ks, source[key], options)
          else
            raise UnknownKeyError.new(key)
          end
        when Enumerable
          select(query, source.to_a, options) # fallback to the array case
        else
          raise UnsupportedContainerError.new(source.class)
      end
    end

    # Similar to {::select}, but writes a value instead of reading it.
    #
    # @param [String] query
    # @param [Object] value
    # @param [Object] source
    def self.update(query, value, source, options={})
      options = {create: false, separator: '/'}.merge(options)
      key, ks = query.split(options[:separator], 2)
      case source
        when Array
          if key.integer?
            if ks.nil?
              if options[:create] || source.index_valid?(key.to_i)
                source[key.to_i] = value
              else
                raise OutOfBoundsError.new(key.to_i, source.size)
              end
            else
              update(ks, value, source[key.to_i], options)
            end
          else
            raise NotAnIndexError.new(key)
          end
        when Hash
          key = key.to_sym if !source.key?(key) && source.key?(key.to_sym)
          if source.key?(key) || options[:create]
            if ks.nil?
              source[key] = value
            else
              unless source.key?(key)
                next_key = ks.split(options[:separator], 2).first
                source[key] = next_key.integer? ? [] : {}
              end
              update(ks, value, source[key], options)
            end
          else
            raise UnknownKeyError.new(key)
          end
        else
          raise UnsupportedContainerError.new(source.class)
      end
    end
  end


end