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
    
    # TODO: Consider moving all config code to a config module or config file.
    #
    class << self
      # Vue::Helpers defaults.
      attr_accessor *%w(
        cache_store
        callback_prefix
        component_call_html
        default_outvar
        external_resource
        external_resource_html
        inline_script_html
        minify
        register_local
        root_app_html
        root_name
        root_object_js
        template_engine
        views_path
        vue_outvar
      )
    end
    
    self.cache_store = {}
    self.callback_prefix = '/vuecallback'
    self.default_outvar = '@_erbout'
    self.external_resource_html = false
    self.minify = false
    self.register_local = false
    self.root_name = 'vue-app'
    self.template_engine = :erb
    self.views_path = 'app/views'
    self.vue_outvar = '@_vue_outvar'
    
    self.component_call_html = '<#{el_name} #{attributes_string}>#{block_content}</#{el_name}>'
    self.external_resource_html = '<script src="#{callback_prefix}/#{key}"></script>'
    self.inline_script_html = '<script>#{compiled}</script>'
    self.root_app_html = '<div id="#{root_name}">#{block_result}</div>#{root_script_output}'
    self.root_object_js = 'var #{app_name} = new Vue({el: ("##{root_name}"), components: {#{components}}, data: #{vue_data_json}})'

  
    # Include this module in your controller (or action, or routes, or whatever).
    #
    # SEE helper_refinements.rb for the helpers' supporting methods!
    #
    module Methods
    
      def self.included(other)
        other.send(:prepend, ControllerPrepend)
      end

            
      def vue_repository
        @vue_repository ||= VueRepository.new(context=self)
        puts "Getting vue_repository #{@vue_repository.class} with keys: #{@vue_repository.keys}"
        @vue_repository
      end
      
      def vue_root(root_name = Vue::Helpers.root_name, **options)
        # @vue_root ||= {}
        # @vue_root[root_name] ||= VueRoot.new(root_name)
        vue_repository.root(root_name, **options)
      end

  
      # Inserts Vue component-call block in html template.
      # Name & file_name refer to file-name.vue.<template_engine> SFC file. Example: products.vue.erb.
      def vue_component(name,
          root_name:Vue::Helpers.root_name,
          attributes:{},
          tag_name:nil,
          file_name:name,
          locals:{},  # may be useless
          template_engine:current_template_engine,
          &block
        )
        
        # Now handled in VueObject.
        #component_content_ary = render_sfc_file(file_name:file_name, locals:locals, template_engine:template_engine)
        
        # Should be handled by VueObject
        #block_content = capture_html(root_name:root_name, **locals, &block) if block_given?
        
        # # Build this later, when processign the vue root.
        # compiled_component_js = compile_component_js(name, *component_content_ary)
        
        # # See new way below.
        # vue_root(root_name).components[name] = {name:name, vue_template:component_content_ary[0], vue_script:component_content_ary[1]}
 
        # # See new way below.
        # component_output = compile_component_html_block(
        #   name: name,
        #   tag_name: tag_name,
        #   attributes: attributes,
        #   block_content: block_content,
        #   locals:locals
        # )


        component = vue_root(root_name).component(name,
          root_name:root_name,
          file_name:file_name,
          template_engine:template_engine,
          context:self        
        )
        puts "Methods#vue_component retrieved component: #{component}"
        
        component_output = component.render(tag_name, locals:locals, attributes:attributes, &block)
        
        if block_given?
          #puts "Vue_component concating content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
          concat_content(component_output)
          #return nil
        else
          #puts "Vue_component returning content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
          return component_output
        end
      end  # vue_component()
    
    
      # Outputs html script block of entire collection of vue roots and components.
      # TODO: Should this use x-templates?
      def vue_app_inline(root_name = Vue::Helpers.root_name, **options)
        #return unless compiled = compile_vue_output(root_name, **options)
        return unless compiled = vue_root(root_name).compile_output_js(**options)
        interpolated_wrapper = Vue::Helpers.inline_script_html.interpolate(compiled: compiled)
      end
  
      # Outputs html script block with src pointing to tmp file on server.
      # Note that x-templates will not work with external-resource scheme,
      # so this will always use template literals (backticks).
      def vue_app_external(root_name = Vue::Helpers.root_name, **options)
        #return unless compiled = compile_vue_output(root_name, **options)
        return unless compiled = vue_root(root_name).compile_output_js(**options)
        key = secure_key
        callback_prefix = Vue::Helpers.callback_prefix
        Vue::Helpers.cache_store[key] = compiled
        interpolated_wrapper = Vue::Helpers.external_resource_html.interpolate(callback_prefix: callback_prefix, key: key)
      end
      
      def vue_app(root_name = Vue::Helpers.root_name, external_resource:Vue::Helpers.external_resource, **options, &block)
        #puts "VUE_ROOT self: #{self}, methods: #{methods.sort.to_yaml}"
        
        #root_app = vue_root(root_name).initialize_options(root_name:root_name, context:self, **options)
        root_app = vue_root(root_name, context:self, **options)
        
        block_result = capture_html(root_name:root_name, **options, &block) if block_given?
        
        root_script_output = case external_resource
        when true; vue_app_external(root_name, **options)
        when String; vue_app_external(root_name, **options)
        else vue_app_inline(root_name, **options)
        end
                
        if block_result
          concat_content(Vue::Helpers.root_app_html.interpolate(
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