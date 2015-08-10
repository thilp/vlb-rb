require 'test/unit'

require_relative '../../lib/vlb/utils'

class TestUtils < Test::Unit::TestCase

  UTILS = VikiLinkBot::Utils

  def test_expand_braces
    assert_equal('b c', UTILS.expand_braces('{b,c}'))
    assert_equal('c', UTILS.expand_braces('{,c}'))
    assert_equal('b', UTILS.expand_braces('{b,}'))

    assert_equal('ab ac', UTILS.expand_braces('a{b,c}'))
    assert_equal('a ac', UTILS.expand_braces('a{,c}'))
    assert_equal('ab a', UTILS.expand_braces('a{b,}'))

    assert_equal('bd cd', UTILS.expand_braces('{b,c}d'))
    assert_equal('d cd', UTILS.expand_braces('{,c}d'))
    assert_equal('bd d', UTILS.expand_braces('{b,}d'))

    assert_equal('abd acd', UTILS.expand_braces('a{b,c}d'))
    assert_equal('ad acd', UTILS.expand_braces('a{,c}d'))
    assert_equal('abd ad', UTILS.expand_braces('a{b,}d'))
  end

end