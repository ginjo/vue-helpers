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
  
  describe 'vue_root' do
    it 'returns a VueRoot instance with default root-name' do
      vue_root_inst = Klas.new.vue_root
      assert_kind_of(Vue::Helpers::VueRoot, vue_root_inst)
      assert_equal vue_root_inst.name, Vue::Helpers.root_name
    end
    
    it 'returns a VueRoot instance with given name' do
      vue_root_inst = Klas.new.vue_root('my-vue-app')
      assert_equal vue_root_inst.name, 'my-vue-app'
    end
  end
  
  describe 'vue_component' do
    let(:mock_controller) {Klas.new}
    let(:vue_component_without_block) { mock_controller.vue_component('my-component', attributes:{color:'red'}) }
    let(:vue_component_with_block) { mock_controller.vue_component('my-component', attributes:{color:'red'}) { 'inner-html text block' } }
    
    it 'returns component html block' do
      assert_equal(vue_component_without_block, '<my-component color="red"></my-component>')
    end
    
    it 'returns component html block with inner text if block passed' do
      assert_equal '<my-component color="red">inner-html text block</my-component>',
        vue_component_with_block
    end
    
    it 'adds component instance to request' do
      #mock_controller.vue_component('my-component')
      vue_component_without_block
      assert_kind_of Vue::Helpers::VueComponent, mock_controller.vue_repository['my-component']
      assert_equal 'my-component', mock_controller.vue_repository['my-component'].name
      assert_equal 'vue-app', mock_controller.vue_repository['my-component'].root_name
    end
  end
  
  describe 'vue_app' do
    let(:mock_controller) {Klas.new}
    
    it 'returns js wrapped in html script tags' do
      #puts VUE_APP_HTML_WITHOUT_BLOCK
      #puts mock_controller.vue_app
      assert_equal VUE_APP_HTML_WITHOUT_BLOCK,  mock_controller.vue_app
    end
    
    it 'prepends vue-app baseline script with inner-html block wrapped in div' do
      assert_equal VUE_APP_HTML_WITH_BLOCK, mock_controller.vue_app(){'vue-app-inner-html'}
    end
  end
end
