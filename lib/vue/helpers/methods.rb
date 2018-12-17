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
    
    @defaults = {
      cache_store:             {},
      callback_prefix:         '/vuecallback',
      default_outvar:          '@_erbout',
      external_resource:       false,
      minify:                  false,
      register_local:          false,
      root_name:               'vue-app',
      template_engine:         :erb, # This should not force template_engine, only recommend if no other can be found.
      template_literal:        true,
      views_path:              'app/views',
      vue_outvar:              '@_vue_outvar',

                               # These are ugly now, becuase I wanted to use double-quotes as the outter-quotes.
      component_call_html:     "<\#{el_name} \#{attributes_string}>\#{block_content}</\#{el_name}>",
      external_resource_html:  "\n<script src=\"\#{callback_prefix}/\#{key}\"></script>",
      inline_script_html:      "\n<script>\#{compiled}\n</script>\n",
      root_app_html:           '<div id="#{root_name}">#{block_result}</div>#{root_script_output}',
      root_object_js:          'var #{app_name} = new Vue({el: ("##{root_name}"), components: {#{components}}, data: #{vue_data_json}})',
      x_template_html:         "\n<script type=\"text/x-template\" id=\"\#{name}-template\">\#{template}</script>",
    }
    
    @defaults.keys.each{|k| define_singleton_method(k){@defaults[k]}}
    
    class << self
      attr_accessor :defaults      
    end
    
        
    # Include this module in your controller (or action, or routes, or whatever).
    #
    # SEE helper_refinements.rb for the helpers supporting methods!
    #
    module Methods
    
      def self.included(other)
        other.send(:prepend, ControllerPrepend)
      end

      def vue_repository
        @vue_repository ||= VueRepository.new(context=self)
        #puts "Getting vue_repository #{@vue_repository.class} with keys: #{@vue_repository.keys}"
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
          file_name:nil,
          locals:{},
          template_engine:nil,
          **attitional_attributes,
          &block
        )
        
        puts "\n\nVue_component '#{name}' with args '#{local_variables.inject({}){ |c, i| c[i.to_s] = eval(i.to_s); c }}'"
        
        # TODO: This should only pass args that are necessary to build the object.
        # Locals should probably be passed here, but not tag_name or attributes or any other per-call params.
        component = vue_root(root_name).component(name,
          root_name:root_name,
          file_name:file_name,
          template_engine:template_engine
        )
        
        component_output = component.render(tag_name, locals:locals, attributes:attributes.merge(attitional_attributes), &block)
        
        if block_given?
          #puts "Vue_component concating content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
          concat_content(component_output)
          #return nil
        else
          #puts "Vue_component returning content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
          return component_output
        end
      end  # vue_component()
    
      
      # TODO: These three methods should be refactored to better manage arg passing.
      # For example, vue_app should pass the root object to .._inline and .._external,
      # so those methods don't have to re-lookup with vue_root(root_name).
    
      # Outputs html script block of entire collection of vue roots and components.
      def vue_app_inline(root_app, root_name = Vue::Helpers.root_name, locals:{}, **options)
        #return unless compiled = compile_vue_output(root_name, **options)
        return unless compiled = root_app.compile_app_js(locals:locals, **options)
        # TODO: Use 'wrapper' here.
        # Returns interpolated_wrapper.
        Vue::Helpers.inline_script_html.interpolate(compiled: compiled, **locals)
      end
  
      # Outputs html script block with src pointing to tmp file on server.
      # Note that x-templates will not work with external-resource scheme,
      # so this will always use template literals (backticks).
      def vue_app_external(root_app, root_name = Vue::Helpers.root_name, locals:{}, **options)
        #return unless compiled = compile_vue_output(root_name, **options)
        return unless compiled = root_app.compile_app_js(locals:{}, **options)
        
        key = secure_key
        Vue::Helpers.cache_store[key] = compiled
        callback_prefix = Vue::Helpers.callback_prefix
        # TODO: Use 'wrapper' here
        # Returns interpolated_wrapper.
        Vue::Helpers.external_resource_html.interpolate(callback_prefix: callback_prefix, key: key, **locals)
      end
      
      def vue_app(root_name = Vue::Helpers.root_name,
          external_resource:  Vue::Helpers.external_resource,
          template_literal:   Vue::Helpers.template_literal,
          minify:             Vue::Helpers.minify,
          locals:             {},
          **options,
          &block
        )
        
         puts "\n\nVue_app '#{root_name}' with args '#{local_variables.inject({}) { |c, i| c[i.to_s] = eval(i.to_s); c }}'"
        
        options.merge!(template_literal:template_literal)
                
        root_app = vue_root(root_name, **options)
        
        # TODO: Should this be moved to VueRoot instance, just like it is for VueComponent?
        # TODO: !! Does this need to be rendered again?
        block_result = capture_html(root_name:root_name, locals:locals, **options, &block) if block_given?
        
        root_script_output = case external_resource
          when true; vue_app_external(root_app, root_name, locals:locals, **options)  #->r{r==true && !template_literal}
          when String; vue_app_external(root_app, root_name, locals:locals, **options)
          else vue_app_inline(root_app, root_name, locals:locals, **options)
        end
        
        #x_templates = vue_root.components.inject(''){|s,c| s << c.get_x_template; s}
        #x_templates = vue_root.components_x_template
        root_script_output.prepend(vue_root.components_x_template.to_s) unless template_literal
                
        if block_result
          # TODO: This should use 'wrapper'.
          concat_content(Vue::Helpers.root_app_html.interpolate(
            # locals
            root_name:root_name,
            block_result:block_result,
            root_script_output:root_script_output,
            **locals
          ))
        else
          root_script_output
        end
      end

      
    end # Methods
  end # Helpers
end # Vue