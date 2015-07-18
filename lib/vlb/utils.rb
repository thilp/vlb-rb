require 'abbrev'
require 'damerau-levenshtein'

module VikiLinkBot
  module Utils

    class VLBError < RuntimeError
    end

    # @param [String] input
    # @param [Array<String>] possibilities
    # @return [Array<String>]
    def guess(input, possibilities)
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
    def expand_braces(str)
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
    def join_multiple(possibilities, intermediate=', ', final=' ou ')
      possibilities.size > 1 ?
          [possibilities[0..-2].join(intermediate), possibilities.last].join(final) :
          possibilities.first
    end

    def unescape_unicode(str)
      str.gsub(/\\u([A-Fa-f0-9]{4})/) { [$1].pack('H*').unpack('n*').pack('U*') }
    end

  end
end