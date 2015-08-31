require 'test/unit'
require 'tempfile'

$: << File.expand_path(__dir__ + '../../lib/')

require_relative '../../lib/vlb/store'

class TestStore < Test::Unit::TestCase

  def setup
    @file = Tempfile.new('vlbtest')
  end

  def test_00_init
    assert_nothing_raised { VikiLinkBot::YamlFileStorage.new }
    assert_nothing_raised { VikiLinkBot::YamlFileStorage.new(@file.path) }
    assert_raise_kind_of(Errno::ENOENT) { VikiLinkBot::YamlFileStorage.new(@file.path + 'unexistent') }
  end

  def test_01_get_empty
    s = VikiLinkBot::YamlFileStorage.new
    assert_equal(42, s.get('a', 42))
  end

  def test_02_set
    s = VikiLinkBot::YamlFileStorage.new
    assert_nothing_raised { s.set('a.b', 2) }
    assert_equal(2, s.get('a.b'))
  end

  def test_02_set_nocreate
    s = VikiLinkBot::YamlFileStorage.new
    assert_raise_kind_of(VikiLinkBot::VLINQ::UnknownKeyError) { s.set('a.b', 2, false) }
  end

  def test_03_write
    s = VikiLinkBot::YamlFileStorage.new(@file.path)
    s.set('a.b', 2)

    s0 = VikiLinkBot::YamlFileStorage.new(@file.path)
    assert_nil(s0.get('a.b'))

    assert_nothing_raised { s.write }

    s2 = VikiLinkBot::YamlFileStorage.new(@file.path)
    assert_equal(2, s2.get('a.b'))
  end

end