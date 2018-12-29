require "test_helper"

class Vue::HelpersTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Vue::Helpers::VERSION
  end

  def test_it_does_something_useful
    assert false
  end
end

describe Vue::Helpers::Methods do
  describe 'vue_root' do
    it 'returns a VueRoot instance' do
      #assert_kind_of
    end
  end
end