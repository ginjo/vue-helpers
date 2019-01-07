require "test_helper"
require 'yaml'

class Klas
  include Vue::Helpers
end

class Vue::HelpersTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Vue::Helpers::VERSION
  end

  def test_adds_core_methods_when_included
    assert Klas.method_defined?(:vue_component)
  end
end

describe Vue::Helpers::Methods do
  let(:mock_controller) {Klas.new}

  describe 'vue_repository' do
    it 'returns a Vue::Helpers::VueRepository instance' do
      assert_kind_of Vue::Helpers::VueRepository, mock_controller.vue_repo
    end
  end
  
  describe 'vue_app' do
    it 'returns a VueRoot instance with default root-name' do
      vue_app_inst = Klas.new.vue_app
      assert_kind_of(Vue::Helpers::VueRoot, vue_app_inst)
      assert_equal vue_app_inst.name, Vue::Helpers.root_name
    end
    
    it 'returns a VueRoot instance with given name' do
      vue_app_inst = Klas.new.vue_app('my-vue-app')
      assert_equal vue_app_inst.name, 'my-vue-app'
    end
  end
  
  describe 'vue_component' do
    let(:vue_component_without_block) { mock_controller.vue_component('test-component', attributes:{color:'red'}) }
    let(:vue_component_with_block) { mock_controller.vue_component('test-component', attributes:{color:'red'}) { 'inner-html text block' } }
    
    it 'returns component html block' do
      assert_equal(vue_component_without_block, '<test-component color="red"></test-component>')
    end
    
    it 'returns component html block with inner text if block passed' do
      assert_equal '<test-component color="red">inner-html text block</test-component>',
        vue_component_with_block
    end
    
    it 'adds component instance to request' do
      #mock_controller.vue_component('test-component')
      vue_component_without_block
      assert_kind_of Vue::Helpers::VueComponent, mock_controller.vue_repository['test-component']
      assert_equal 'test-component', mock_controller.vue_repository['test-component'].name
      assert_equal 'vue-root', mock_controller.vue_repository['test-component'].root_name
    end
  end
  
  describe 'vue_root' do    
    it 'returns js wrapped in html script block' do
      #puts VUE_ROOT_HTML_WITHOUT_BLOCK
      #puts mock_controller.vue_root
      assert_equal VUE_ROOT_HTML_WITHOUT_BLOCK,  mock_controller.vue_root
    end
    
    it 'prepends vue-root baseline script with inner-html block wrapped in div' do
      assert_equal VUE_ROOT_HTML_WITH_BLOCK, mock_controller.vue_root(){'vue-root-inner-html'}
    end
    
    it 'includes component objects in script block' do
      mock_controller.vue_component('test-component')
      output = mock_controller.vue_root
      assert output.lines[4][/test-component inner text/]
      assert output.lines[12][/var VueRoot = new Vue.*vue-root.*TestComponent/]
    end
  end
end
