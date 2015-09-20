require 'test/unit'
require_relative '../../lib/vlb/wikilink_resolver'

class Link
  attr_accessor :target, :title, :braces, :checked, :wiki
  def initialize(target, options={})
    options = {title: nil, braces: %w<[[ ]]>, checked: true, wiki: nil}.merge(options)
    @target = target.to_s
    @title = options[:title]
    @braces = options[:braces].take(2).map(&:to_s)
    @checked = options[:checked]
    @wiki = WikiFactory.expand_domain(options[:wiki])
  end
  def to_s
    l = @braces.first
    l += ':' unless @checked
    l += "#{@wiki}:" if @wiki
    l += target
    l += "|#{@title}" if @title
    l + @braces.last
  end
end

class TestWikilinkResolver < Test::Unit::TestCase

  R = VikiLinkBot::WikiLinkResolver

  def test_wikilinks_in
    tested_links = [
        Link.new('a'),
        Link.new('x Y'),
        Link.new('Bc', wiki: 'en'),
        Link.new('toto', checked: false, title: 'some guy'),
        Link.new('toto & Cie', braces: %w<(( ))>),
        Link.new('toto & Cie (Game)', braces: %w<(( ))>),
        Link.new('(new) toto & Cie (Game)', braces: %w<(( ))>),
        Link.new('[', braces: %w<(( ))>),
        Link.new('('),
    ]
    res = R.wikilinks_in(tested_links.join(' '))
    assert_kind_of(Enumerable, res)
    assert_equal(tested_links.size, res.size, 'all but no more links detected')
    p tested_links.map(&:to_s), res.map(&:to_s)
    tested_links.zip(res).each do |expected, got|
      assert_instance_of(Wikilink, got)
      assert_equal(expected.target, got.pagename)
      assert_equal(expected.wiki, got.wiki.domain)
      assert_equal(expected.checked, got.state != 0)
    end
  end

end