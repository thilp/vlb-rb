require 'test/unit'

$DONT_LOAD_SHELL_COMMANDS = true
require_relative '../../lib/vlb/shell-core'

class TestShellCore < Test::Unit::TestCase

  SH = VikiLinkBot::Shell
  IN = VikiLinkBot::Input

  def test_input_split
    [%w<>, %w< a >, %w< a b c >, %w< @a >, %w< a@a >, %w< ! >, %w< !abc @k >].each do |t|
      assert_equal(t, IN.split(t.join(' ')), "Input::split(#{t.inspect})")
    end

    # Brace expansion
    assert_equal(%w<ab ac>, IN.split('a{b,c}'))
    assert_equal(%w<a ac>, IN.split('a{,c}'))
    assert_equal(%w<ab a>, IN.split('a{b,}'))
    assert_equal(%w<@ab @a>, IN.split('@a{b,}'))
    assert_equal(%w<!ab !a>, IN.split('!a{b,}'))
    assert_equal(['he{l,l}o world'], IN.split('"he{l,l}o world"'), 'no brace expansion in strings, but quotes removed')
  end

end