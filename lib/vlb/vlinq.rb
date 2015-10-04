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
        "#{@type} : conteneur inconnu"
      end
    end
    class NotAnIndexError < VLINQError
      attr_reader :access
      def initialize(access)
        @access = access
      end
      def message
        "#{@access.inspect} : type d'index invalide (#{@access.class})"
      end
    end
    class OutOfBoundsError < VLINQError
      attr_reader :access, :size
      def initialize(access, size)
        @access = access
        @size = size
      end
      def message
        "index #{@access} invalide dans un tableau de #{@size} éléments"
      end
    end
    class UnknownKeyError < VLINQError
      attr_reader :key
      def initialize(key, alternatives=[])
        @key = key
        @alternatives = alternatives
      end
      def message
        "clef #{@key.inspect} inconnue" +
            (@alternatives.none? ? '' :
                ' ; alternatives : ' + VikiLinkBot::Utils.join_multiple(@alternatives))
      end
    end

    # Returns the value corresponding to the specified query in the specified source.
    # The separator is used to break the query into path components that are interpreted,
    # depending on source's type, as indices (Array) or keys (Hash).
    #
    # @param [String] query a sequence of tokens (separated by separator) describing how to access the targeted value
    # @param [Object] source the (possibly nested) container in which to search for the targeted value
    # @param [TrueClass,FalseClass] create whether to create a queried but non-existent path
    # @param [String] separator what stands between each query part
    # @param [TrueClass,FalseClass] alternative_keys whether to include an alternative key list in the exception for
    #   an unknown key
    #
    # @raise [OutOfBoundsError] when trying to access an offset greater than the array's size
    # @raise [NotAnIndexError] when trying to access an offset with something else than an integer
    # @raise [UnknownKeyError] when trying to access an unknown field in a hash
    # @raise [UnsupportedContainerError] when querying an unknown container type
    def self.select(query, source, create: false, separator: '/', alternative_keys: false)
      key, ks = query.split(separator, 2)
      case source
        when Array
          if key.integer?
            if create || source.index_valid?(key.to_i)
              ks.nil? ? source[key.to_i] : select(ks, source[key.to_i], options)
            else
              raise OutOfBoundsError.new(key.to_i, source.size)
            end
          else
            raise NotAnIndexError.new(key)
          end
        when Hash
          key = key.to_sym if !source.key?(key) && source.key?(key.to_sym)
          if create || source.key?(key)
            ks.nil? ? source[key] : select(ks, source[key], options)
          else
            raise UnknownKeyError.new(key, alternative_keys ? source.keys : [])
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
    # @param [TrueClass,FalseClass] create
    # @param [String] separator
    def self.update(query, value, source, create: false, separator: '/')
      key, ks = query.split(separator, 2)
      case source
        when Array
          if key.integer?
            if ks.nil?
              if create || source.index_valid?(key.to_i)
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
          if source.key?(key) || create
            if ks.nil?
              source[key] = value
            else
              unless source.key?(key)
                next_key = ks.split(separator, 2).first
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