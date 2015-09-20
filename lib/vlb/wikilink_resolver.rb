require 'cinch'
require 'vlb/wiki'
require 'vlb/utils'
require 'vlb/watcher'

module VikiLinkBot
  class WikiLinkResolver
    include Cinch::Plugin

    match /\[\[|\(\(/, strip_colors: true, use_prefix: false

    def execute(m)
      return if m.channel && VikiLinkBot::Watcher.trusted_sources.key?(m.channel.name)
      wikilinks = self.class.wikilinks_in(Utils.expand_braces(m.message))
      self.class.update_wikilink_states(wikilinks)
      m.reply wikilinks.join(' · ')
    end

    def self.wikilinks_in(str)
      wikis = WikiFactory.instance
      find_wikilinks(str, %w<[[ ]]>, wikis) + find_wikilinks(str, %w<(( ))>, wikis)
    end

    def self.find_wikilinks(str, braces, wikis)
      links = {}
      b = {a: :first, z: :last}.map { |k, v| [k, braces.send(v).chars.map { |c| Regexp.quote(c) }] }.to_h
      ctnt = %r%
        (?: (?! #{b[:z].join} (?! #{b[:z].first} ) |
                \| )
            . )
      %x
      str.scan %r%
               #{b[:a].join}
               ( #{ctnt}+ )
               (?: \| #{ctnt}* )?
               #{b[:z].join}
               %x do |pagename, _|
        pagename.strip!

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
      wikis = {}
      links.each { |link| (wikis[link.wiki] ||= []) << link if link.state == 1 }  # Builds a {wiki => [links]} map
      wikis.each do |wiki, link_list|
        states = wiki.page_states(*link_list.map(&:pagename))
        link_list.each { |link| link.state = states[link.pagename] }
      end
    end

  end
end