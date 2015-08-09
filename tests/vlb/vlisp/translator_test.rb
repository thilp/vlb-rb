require 'test/unit'

require_relative '../../../lib/vlb/vlisp/reader'
require_relative '../../../lib/vlb/vlisp/translator'

class TestVLispTranslator < Test::Unit::TestCase

  VLISP = VikiLinkBot::VLisp

  def my_translate(expr, _json=nil)
    eval(VLISP.translate_expr(VLISP.parse_expr(VLISP.tokenize(expr))))
  end

  def test_010_translate_expr_atomic_truth
    assert_true(my_translate('#t'))
    assert_false(my_translate('#f'))
  end

  def test_011_translate_expr_atomic_numbers
    assert_equal(17, my_translate('17'))
    assert_equal(-5, my_translate('-5'))
    assert_equal(6.2, my_translate('6.2'))
    assert_equal(-14.888, my_translate('-14.888'))
    assert_equal(2000000, my_translate('2_000_000'))

    # Hexadecimal
    assert_equal(0xdeadbeef, my_translate('0xdeadbeef'))
    assert_equal(0xdeadbeef, my_translate('0x_dead_beef'))
    assert_equal(-0xdeadbeef, my_translate('-0xdeadbeef'))
    assert_raise { my_translate('0xabc.def') }
  end

  def test_012_translate_expr_atomic_strings
    assert_equal('hello world', my_translate('"hello world"'))
    assert_equal('\\""', my_translate('"\\\\\\"\\""'))
  end


  def test_013_translate_expr_jsonrefs
    _json = {'a' => 2, 'b' => {'c' => 'bc'}}

    assert_equal(2, my_translate('a', _json))
    assert_equal('bc', my_translate('b/c', _json))

    assert_raise_kind_of(VLISP::UnrecognizedTokenError) { my_translate('b/c/', _json) }
    assert_raise_kind_of(VLISP::UnrecognizedTokenError) { my_translate('/b/c/', _json) }

    assert_false(my_translate('nonexistent', _json))
  end

  def test_100_translate_expr_variadic_ops
    assert_equal(5, my_translate('( + 2 3 )'))
    assert_equal(6, my_translate('( + 1 2 3 )'))
    assert_equal(5.2, my_translate('( + 2.2 3 )'))

    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( + )') }

    assert_equal(-4, my_translate('( + -4 )'))

    assert_equal(12, my_translate('( + ( + 3 4 ) ( + 2 3 ) )'))
  end

  def test_100_translate_expr_binary_ops
    assert_true(my_translate('( < 1 2 )'))
    assert_false(my_translate('( < 2 1 )'))
    assert_true(my_translate('( < 1 2 3 )'))
    assert_false(my_translate('( < 2 1 3 )'))

    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( < )') }
    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( < 1 )') }

    # Ruby type errors are trapped and converted to false
    assert_false(my_translate('( < 1 #t )'))
    assert_false(my_translate('( < #t 1 )'))
  end

  def test_100_translate_expr_methods
    # EMPTY?
    assert_true(my_translate('( EMPTY? "" )'))
    assert_false(my_translate('( EMPTY? "x" )'))
    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( EMPTY? "x" "y" )') }
    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( EMPTY? )') }

    # SIZE
    assert_equal(0, my_translate('( SIZE "" )'))
    assert_equal(3, my_translate('( SIZE "abc" )'))
  end

  def test_100_translate_expr_not
    assert_false(my_translate('( NOT #t )'))
    assert_true(my_translate('( NOT #f )'))
    assert_false(my_translate('( NOT #f #t )'), 'variadic NOT is ANDed')
    assert_true(my_translate('( NOT #f ( < 3 1 ) #f )'))
    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( NOT )') }
  end

  def test_100_translate_expr_if
    assert_equal(3, my_translate('( IF #t 3 4 )'))
    assert_equal(4, my_translate('( IF #f 3 4 )'))
    assert_equal(3, my_translate('( IF ( < 1 2 ) 3 4 )'))
    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( IF #t 3 )') }
    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( IF #t )') }
    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( IF )') }
    assert_raise_kind_of(VLISP::InvalidArityError) { my_translate('( IF #t 3 4 5 )') }
  end

  def test_100_translate_expr_json_equals
    _json = {'a' => 2, 'b' => {'c' => 'bc'}}
    assert_true(my_translate('a:2', _json))
    assert_false(my_translate('a:3', _json))

    assert_true(my_translate('b/c:bc', _json))
    assert_true(my_translate('b/c:"bc"', _json))
    assert_false(my_translate('b/c:nope', _json))
    assert_false(my_translate('b/c:"nope"', _json))

    assert_false(my_translate('nonexistent:4', _json))

    assert_raise_kind_of(VLISP::UnexpectedEOFError) { my_translate('a:', _json) }
  end

  def only_translate(str)
    VLISP.translate_expr(VLISP.parse_expr(VLISP.tokenize(str)))
  end

  def test_200_no_useless_cocoon
    assert_false(only_translate('#t').include?('begin'))
    assert_false(only_translate('21.3').include?('begin'))
    assert_true(only_translate('some_ref').include?('begin'))
    assert_true(only_translate('(+ 1 some_ref)').include?('begin'))
  end

end