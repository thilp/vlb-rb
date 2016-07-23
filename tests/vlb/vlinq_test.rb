require 'test/unit'
require_relative '../../lib/vlb/vlinq'

class TestVLINQ < Test::Unit::TestCase

  def setup
    @source = {
        'string_key' => 1,
        sym_key: 1,
        'array' => %w( a b c ),
        'nested_hash' => {},
        'other_hash' => {'a' => 0, 'b' => 1},
        'hash_with_sym_keys' => {a: 0, b: 1},
    }
  end

  def test_string_extensions_integer
    assert_true('0'.integer?)
    assert_true('-2'.integer?)

    assert_false('a'.integer?)
    assert_false('a5'.integer?)
    assert_false('5a'.integer?)
    assert_false('-a'.integer?)
    assert_false('-5a'.integer?)

    assert_true('+5'.integer?)
    assert_false('+5a'.integer?)

    assert_false('5.1'.integer?, 'floating-point numbers are not integers')
    assert_false('+5.1'.integer?)
    assert_false('-5.1'.integer?)

    assert_false('5.1a'.integer?)
    assert_false('+5.1a'.integer?)
    assert_false('-5.1a'.integer?)
    assert_false('5a.1'.integer?)
    assert_false('+5a.1'.integer?)
    assert_false('-5a.1'.integer?)

    assert_false('5.1.0'.integer?)
  end

  def test_select_simple
    assert_equal(1, VikiLinkBot::VLINQ.select('string_key', @source), 'single string key')
    assert_equal(1, VikiLinkBot::VLINQ.select('sym_key', @source), 'single symbol key')
    assert_equal(%w( a b c ), VikiLinkBot::VLINQ.select('array', @source), 'returns an array')
    assert_equal({}, VikiLinkBot::VLINQ.select('nested_hash', @source), 'returns a hash')
  end

  def test_select_multipart
    assert_equal(1, VikiLinkBot::VLINQ.select('other_hash/b', @source, separator: '/'), 'two-parts query')
    assert_equal('a', VikiLinkBot::VLINQ.select('array/0', @source, separator: '/'), 'two-parts query with an index')
    assert_equal(1, VikiLinkBot::VLINQ.select('hash_with_sym_keys/b', @source, separator: '/'), 'two-parts query with symbol')
  end

  def test_select_invalid_access
    assert_raise_kind_of(VikiLinkBot::VLINQ::NotAnIndexError) { VikiLinkBot::VLINQ.select('array/b', @source, separator: '/') }
    assert_raise_kind_of(VikiLinkBot::VLINQ::OutOfBoundsError) { VikiLinkBot::VLINQ.select('array/7', @source, separator: '/') }
    assert_raise_kind_of(VikiLinkBot::VLINQ::UnknownKeyError) { VikiLinkBot::VLINQ.select('nested_hash/k', @source, separator: '/') }
  end

  def test_select_create
    assert_nil(VikiLinkBot::VLINQ.select('array/7', @source, separator: '/', create: true), '"create" creates and return nil array entry')
  end

  def test_select_wtf
    assert_raise_kind_of(VikiLinkBot::VLINQ::UnsupportedContainerError) { VikiLinkBot::VLINQ.select('a/b', nil) }
  end

  def test_update_simple
    h = {a: 1}
    assert_nothing_raised { VikiLinkBot::VLINQ.update('a', 2, h) }
    assert_equal(2, h[:a], 'value has been updated')
  end

  def test_update_create_simple
    h = {}
    assert_raise_kind_of(VikiLinkBot::VLINQ::UnknownKeyError) { VikiLinkBot::VLINQ.update('a', 2, h) }
    assert_false(h.key?('a'), 'value has not been updated (as string)')
    assert_false(h.key?(:a), 'value has not been updated (as symbol)')
    assert_nothing_raised { VikiLinkBot::VLINQ.update('a', 2, h, create: true) }
    assert_false(h.key?(:a), 'value has not been updated (as symbol)')
    assert_equal(2, h['a'], 'value has been updated (as string)')
  end

  def test_update_create_nested
    h = {}
    assert_raise_kind_of(VikiLinkBot::VLINQ::UnknownKeyError) { VikiLinkBot::VLINQ.update('a/b', 2, h) }
    assert_false(h.key?('a'), 'value has not been updated (as string)')
    assert_false(h.key?(:a), 'value has not been updated (as symbol)')
    assert_nothing_raised { VikiLinkBot::VLINQ.update('a/b', 2, h, create: true) }
    assert_false(h.key?(:a), 'value has not been updated (as symbol)')
    assert_equal(2, h['a']['b'], 'value has been updated (as string)')
  end

  def test_update_create_nested_array
    h = {}
    assert_raise_kind_of(VikiLinkBot::VLINQ::UnknownKeyError) { VikiLinkBot::VLINQ.update('a/2', 2, h) }
    assert_false(h.key?('a'), 'value has not been updated (as string)')
    assert_false(h.key?(:a), 'value has not been updated (as symbol)')
    assert_nothing_raised { VikiLinkBot::VLINQ.update('a/2', 2, h, create: true) }
    assert_false(h.key?(:a), 'value has not been updated (as symbol)')
    assert_kind_of(Array, h['a'], 'an array (not a hash) has been autovivified since the key was an integer')
    assert_equal(2, h['a'][2], 'value has been updated (as string)')
  end

end