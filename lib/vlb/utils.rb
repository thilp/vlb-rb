require 'abbrev'
require 'damerau-levenshtein'

module VikiLinkBot
  def intercept(default, &block)
    begin
      yield(block)
    rescue
      default
    end
  end

  module Utils

    class VLBError < RuntimeError
    end

    # @param [String] input
    # @param [Array<String>] possibilities
    # @return [Array<String>]
    def self.guess(input, possibilities)
      # Start guessing using abbreviations
      guesses = possibilities.abbrev(input).values.uniq
      return guesses if guesses.size == 1

      # If no abbreviation is satisfying, try Levenshtein
      guesses = possibilities.map { |p| [p, DamerauLevenshtein.distance(input, p.to_s, 1, 4)] }
                    .select  { |_, d| d < 5 && d <= 2 * input.size / 3.0 }
                    .sort_by { |_, d| d }

      guesses.take_while { |_, d| d <= guesses.first.last } # consider only the best ones
             .map { |p, _| p } # loose the array, we don't care about the distance anymore
    end

    # @param [String] str
    # @return [String]
    def self.expand_braces(str)
      new_str = str
      loop do
        tmp = new_str.gsub /(\S*) \{ ( [^,\}]* (?: , [^,\}]* )+ ) \} (\S*)/x do
          $2.split(',').map { |t| $1 + t + $3 }.join(' ')
        end
        break if tmp == new_str
        new_str = tmp
      end
      new_str
    end

    # @param [Array<String>] possibilities
    # @return [String]
    def self.join_multiple(possibilities, intermediate=', ', final=' ou ')
      possibilities.size > 1 ?
          [possibilities[0..-2].join(intermediate), possibilities.last].join(final) :
          possibilities.first
    end

    # @param [String] str
    def self.unescape_unicode(str)
      str.gsub(/\\u([A-Fa-f0-9]{4})/) { [$1].pack('H*').unpack('n*').pack('U*') }
    end

    # Copies string, but changes arrays and hashes in place.
    # @param [Hash] json
    def self.unescape_unicode_in_values(json)
      case json
        when String
          unescape_unicode(json)
        when Array
          json.map!(&:unescape_unicode_in_values)
        when Hash
          json.each do |k, v|
            json[k] = unescape_unicode_in_values(v)
          end
          json
        else
          raise "unsupported type #{json.class}"
      end
    end

  end
end