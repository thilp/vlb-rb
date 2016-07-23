require 'cinch'
require 'vlb/wiki'
require 'vlb/utils'
require 'vlb/watcher'

module VikiLinkBot
  class WikiLinkResolver
    include Cinch::Plugin

    match /\[\[|\(\(/, strip_colors: true, use_prefix: false

    def execute(m)
      wikilinks = self.class.wikilinks_in(Utils.expand_braces(m.message))
      self.class.update_wikilink_states(wikilinks)
      m.reply wikilinks.join(' · ')
    end

    class BracePair
      attr_reader :opening, :closing

      # @param [String] opening
      # @param [String] closing
      def initialize(opening, closing)
        @opening, @closing = [opening, closing].map { |x| x.chars.map { |c| Regexp.quote(c) } }
      end

      def matcher
        content = %r{
        (?: (?! #{closing.join}
                (?! #{closing.first} )
              | \| )
            . )
      }x

        %r{
        #{opening.join}
        ( #{content}+ )
        (?: \| #{content}* )?
        #{closing.join}
        }x
      end
    end

    REGEX = Regexp.new( [%w<[[ ]]>, %w<(( ))>].map { |braces| BracePair.new(*braces).matcher }.join('|') )

    def self.wikilinks_in(str)
      wikis = WikiFactory.instance
      links = {}
      str.scan(REGEX) do |captures|
        pagename = captures.compact.first.strip

        # A ":" prefix means that we don't want to check whether the page exists.
        check = true
        pagename.sub!(/^:+\s*/) { check = false; '' }

        # A "something:" prefix specifies where to look for the page.
        wiki = pagename.sub!(/^([a-z.-]+):+\s*/, '') ? wikis.get($1) : wikis.get('fr.vikidia.org')

        hash = [wiki, pagename]
        if links[hash]
          links[hash] = Wikilink.new(wiki, pagename, check) if check && links[hash].state == 0
        else
          links[hash] = Wikilink.new(wiki, pagename, check)
        end

      end
      links.values
    end

    def self.update_wikilink_states(links)
      WikiLinkSet.new.concat(links).compute_states!
    end

  end
end