require 'test/unit'

require_relative '../../../lib/vlb/vlisp/reader'

class TestVLispReader < Test::Unit::TestCase

  VLISP = VikiLinkBot::VLisp

  def tokenize_helper(ary)
    VLISP.tokenize(ary.join(' ')).map(&:text)
  end

  def test_00_tokenize
    truths = %w< #t #f >
    assert_equal(truths, tokenize_helper(truths))

    numbers = %w< 0 1 2.2 -3 -4.4_02 0x5 -0x_dead_beef >
    assert_equal(numbers, tokenize_helper(numbers))
    assert_raise_kind_of(VLISP::UnrecognizedTokenError) { VLISP.tokenize('0x2.5') }

    strings = ['""', '"abc"', '" def ghi jkl "', '"a\\"\\b\\\\"']
    assert_equal(strings, tokenize_helper(strings))
    assert_raise_kind_of(VLISP::UnrecognizedTokenError) { VLISP.tokenize('"a\\"') }

    regexes = ['//', '/a/', '/ a b c /', '/\\//']
    regexes = regexes.concat(regexes.map { |e| e + 'xi' })
    assert_equal(regexes, tokenize_helper(regexes))

    jsonrefs = %w< a a/b c_d/e-f/gh >
    assert_equal(jsonrefs, tokenize_helper(jsonrefs))

    assert_equal(%w{ ( IF ( + -a 3.2 ) #t ( = 2 a/b/c ) ) },
                 VLISP.tokenize('(IF (+ -a 3.2) #t (= 2 a/b/c))').map(&:text))

    assert_equal(%w{ a : #t }, VLISP.tokenize('a:#t').map(&:text))
    assert_equal(%w{ a : ( < 1 2 ) }, VLISP.tokenize('a:(< 1 2)').map(&:text))
    assert_equal(%w{ a : /ab\\/c/i }, VLISP.tokenize('a:/ab\\/c/i').map(&:text))
  end

  def test_01_parse_expr
    assert_raise_kind_of(VLISP::UnexpectedEOFError) { VLISP.parse_expr([]) }

    stream = VLISP.tokenize('2.2')
    assert_equal(stream.first, VLISP.parse_expr(stream), 'a single token is returned unchanged')

    stream = VLISP.tokenize('(+ 1 2)')
    assert_equal(%w( + 1 2 ), VLISP.parse_expr(stream).map(&:text), 'a flat, braced expression is returned without braces')

    res = VLISP.parse_expr(VLISP.tokenize('(+ (- 1 2) 3)'))
    assert_equal(%w{ + - 1 2 3 }, res.flatten.map(&:text))
    assert_true(res.size == 3)
    assert_true(res[1].is_a?(Array))

    res = VLISP.parse_expr(VLISP.tokenize('a/b:"abc"'))
    assert_equal(%w{ LIKE a/b "abc" }, res.map(&:text), '<jsonref>:<vlisp> is transformed into (LIKE <jsonref> <vlisp>)')

    assert_raise_kind_of(VLISP::UnexpectedEOFError) { VLISP.parse_expr(VLISP.tokenize('(a (b)')) }
    assert_raise_kind_of(VLISP::UnexpectedClosingBraceError) { VLISP.parse_expr(VLISP.tokenize(')a')) }

    stream = VLISP.tokenize('(+ 1 2 3) a (b x y)')
    assert_equal(%w( + 1 2 3 ), VLISP.parse_expr(stream).map(&:text), 'parse_expr ignores what comes after a complete expression')
  end

end