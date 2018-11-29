require 'securerandom'
require 'tilt'
require 'erb'

require_relative 'helper_refinements'
require_relative 'utilities'
require_relative 'vue_root'

module Vue
  module Helpers
    using CoreRefinements
    using HelperRefinements
    
    class << self
      # Vue::Helpers defaults.
      attr_accessor *%w(
        cache_store
        callback_prefix
        component_wrapper_html
        default_outvar
        external_js_wrapper_html
        inline_js_wrapper_html
        root_app_wrapper_html
        root_name
        root_object_js
        template_engine
        views_path
        vue_outvar
      )
    end
    
    self.cache_store = {}
    self.callback_prefix = '/vuecallback'
    self.component_wrapper_html = '<#{el_name} #{attributes_string}>#{block_content}</#{el_name}>'
    self.default_outvar = '@_erbout'
    self.external_js_wrapper_html = '<script src="#{callback_prefix}/#{key}"></script>'
    self.inline_js_wrapper_html = '<script>#{compiled}</script>'
    self.root_app_wrapper_html = '<div id="#{root_name}">#{block_result}</div>#{root_script_output}'
    self.root_name = 'vue-app'
    self.root_object_js = 'var #{app_name} = new Vue({el: ("##{root_name}"), components: {#{components}}, data: #{vue_data_json}})'
    self.template_engine = :erb
    self.views_path = 'app/views'
    self.vue_outvar = '@_vue_outvar'
    
  
    # Include this module in your controller (or action, or routes, or whatever).
    #
    # SEE helper_refinements.rb for the helpers' supporting methods!
    #
    module Methods
    
      def self.included(other)
        other.send(:prepend, ControllerPrepend)
      end
      
      # Stores all root apps defined by vue-helpers, plus their compiled components.
      def vue_app(root_name = Vue::Helpers.root_name)
        @vue_app ||= {}
        @vue_app[root_name.to_s] ||= RootApp.new
      end
  
      # Inserts Vue component-call block in html template.
      # Name & file_name refer to file-name.vue.<template_engine> SFC file. Example: products.vue.erb.
      def vue_component(name,
          root_name:Vue::Helpers.root_name,
          attributes:{}, tag:nil,
          file_name:name,
          locals:{},
          template_engine:current_template_engine,
          &block
        )
        #puts "VUE_COMPONENT called with name: #{name}, root_name: #{root_name}, tag: #{tag}, file_name: #{file_name}, template_engine: #{template_engine}, block_given? #{block_given?}"
        #puts self.class
        #[instance_variables, local_variables].flatten.each{|v| puts "#{v}: #{eval(v.to_s)}"}; nil
        #puts "block.binding.eval(#{@outvar}) : #{block.binding.eval(@outvar.to_s)}"
        
        component_content_ary = render_sfc_file(file_name:file_name, locals:locals, template_engine:template_engine)
        #puts "VC #{name} component_content_ary: #{component_content_ary}"
        
        block_content = render_block(locals:locals, template_engine:template_engine, &block) if block_given?
        #puts "VC #{name} block_content: #{block_content}"
        
        # Build this later, when processign the vue root.
        #compiled_component_js = compile_component_js(name, *component_content_ary)
        #puts "VC #{name} compiled_component_js: #{compiled_component_js}"
        
        vue_app(root_name).components[name] = {name:name, vue_template:component_content_ary[0], vue_script:component_content_ary[1]}
        
        component_output = compile_component_html_block(
          name: name,
          tag: tag,
          attributes: attributes,
          block_content: block_content,
          locals:locals
        )
         #puts "VC output for '#{name}': #{component_output}"
        
        if block_given?
          #puts "Vue_component concating content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
          concat_content(component_output)
          #return nil
        else
          #puts "Vue_component returning content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
          return component_output
        end
        
        #puts "@outvar: #{@outvar}: #{eval('@' + @outvar) if @outvar}"
        #puts "@_out_buf: #{@_out_buf}"
        # result
      end
    
      # Ouputs html script block of entire collection of vue roots and components.
      def vue_root_inline(root_name = Vue::Helpers.root_name, **options)
        #puts "VUE: #{vue}"
        return unless compiled = compile_vue_output(root_name, **options)
        interpolated_wrapper = Vue::Helpers.inline_js_wrapper_html.interpolate(compiled: compiled)
      end
  
      # Outputs html script block with src pointing to tmp file on server.
      def vue_root_external(root_name = Vue::Helpers.root_name, **options)
        return unless compiled = compile_vue_output(root_name, **options)
        key = secure_key
        callback_prefix = Vue::Helpers.callback_prefix
        Vue::Helpers.cache_store[key] = compiled
        interpolated_wrapper = Vue::Helpers.external_js_wrapper_html.interpolate(callback_prefix: callback_prefix, key: key)
      end
      
      def vue_root(root_name = Vue::Helpers.root_name, external_resource:false, **options, &block)
        #puts "VUE_ROOT self: #{self}, methods: #{methods.sort.to_yaml}"
        block_result = capture_html(&block) if block_given?
        
        root_script_output = case external_resource
        when true; vue_root_external(root_name, **options)
        when String; vue_root_external(root_name, **options)
        else vue_root_inline(root_name, **options)
        end
        
        if block_result
          concat_content(Vue::Helpers.root_app_wrapper_html.interpolate(
            # locals
            root_name:root_name,
            block_result:block_result,
            root_script_output:root_script_output
          ))
        else
          root_script_output
        end
      end
      
    end # Methods
  end # Helpers
end # Vue