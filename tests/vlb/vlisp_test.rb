require 'test/unit'

require_relative '../../lib/vlb/vlisp'

class TestVLisp < Test::Unit::TestCase

  VLISP = VikiLinkBot::VLisp

  def test_lisp2ruby
    assert_equal(eval(VLISP.lisp2ruby('(+ 1 3)') + '&&' + VLISP.lisp2ruby('#t')),
                 eval(VLISP.lisp2ruby('(+ 1 3) #t', enclose_with_and: true)),
                 'enclose_with_and effectively ANDs multiple results')

    assert_raise_kind_of(VLISP::AlwaysFalseError) { VLISP.lisp2ruby('#f', check_anticipated: true) }
    assert_raise_kind_of(VLISP::AlwaysTrueError) { VLISP.lisp2ruby('(AND #t (< 1 3))', check_anticipated: true) }
  end

end