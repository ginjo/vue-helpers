require 'securerandom'
require_relative 'utilities'
require_relative 'helper_refinements'
require_relative 'vue_object'

module Vue
  module Helpers
    using CoreRefinements
    using HelperRefinements
    
    class VueRoot < VueObject
      def type; 'root'; end
      
      @defaults = {
        #app_name:           nil,
        external_resource:  nil,
        template_literal:   nil,
        register_local:     nil,
        minify:             nil,
        #locals:             {},
      }
      
      attr_accessor *defaults.keys
      
      ###  Under Construction
      # Renders the html block to replace ruby vue_app tags.
      #def render(tag_name=nil, locals:{}, attributes:{}, &block) # From vue_component
      def render(locals:{}, **options, &block)
        #puts "\nVueRoot#render with locals: #{locals}, options: #{options}, self: #{self}"
        #print_ivars
        
        block_content = context.capture_html(root_name:name, locals:locals, &block) if block_given?
        
        compiled_js = compile_app_js(locals:locals, **options)

        root_script_output = case external_resource
          # TODO: Handle external_resource:<some-string> if necessary.
          #when String; vue_app_external(root_app, root_name, locals:locals, **options)
          when true;
            #vue_app_external(root_app, root_name, locals:locals, **options)  #->r{r==true && !template_literal}
            key = SecureRandom.urlsafe_base64(32)
            Vue::Helpers.cache_store[key] = compiled_js
            callback_prefix = Vue::Helpers.callback_prefix
            wrapper(:external_resource_html, callback_prefix:callback_prefix, key:key, **locals)
          else
            #vue_app_inline(root_app, root_name, locals:locals, **options)
            wrapper(:inline_script_html, compiled:compiled_js, **locals)
        end

        root_script_output.prepend(components_x_template.to_s) unless template_literal
        
        # TODO: Are locals being passed properly here?
        if block_given?
          wrapper(:root_app_html,
            root_name:name,
            block_content:block_content,
            root_script_output:root_script_output,
            **locals
          )
        else
          root_script_output
        end
      end
      
      def app_name
        @app_name || js_var_name
      end
            
      # Gets or creates a related component.
      def component(_name, **options)
        repo.component(_name, **options.merge({root_name:(name || root_name)}))
      end
      
      # Selects all related components.
      def components
        repo.select{|k,v| v.type == 'component' && v.root_name == name}.values
      end
      
      def component_names
        components.map{|c| c.js_var_name}.join(', ')
      end
      
      # Returns JS string of all component object definitions.
      def components_js(**options)
        #puts "\nVueRoot#componenets_js called with components: #{components.map(&:name)}"
        components.map{|c| c.to_component_js(**options)}.join("\n")
      end
      
      # Returns HTML string of component vue templates in x-template format.
      def components_x_template
        components.map{|c| c.get_x_template}.join("\n")
      end      
      
      # Compiles js output (components & root) for entire vue-app for this root object.
      # If template_literal is false, only the js object definitions are included.
      # In that case, the vue template html is left to be rendered in x-template blocks.
      # TODO: Clean up args, especially locals handling.
      def compile_app_js(locals:{}, **options  # generic opts placeholder until we get the args/opts flow worked out.
          # root_name = Vue::Helpers.root_name,
          # file_name:root_name,
          # app_name:root_name.camelize, # Maybe obsolete, see js_var_name
          # #template_engine:context.current_template_engine,
          # register_local: Vue::Helpers.register_local,
          # minify: Vue::Helpers.minify,
          # # Block may not be needed here, it's handled in 'vue_app'.
          # &block
        )
        
        # TODO: Make these locals accessible from anywhere within the root instance,
        #   as we also need them for the 'render' method.
        locals = {
          root_name:        name.to_s.kebabize,
          #app_name:         (options[:app_name] || js_var_name),
          app_name:         js_var_name,
          file_name:        file_name,
          template_engine:  template_engine,
          components:       component_names,
          vue_data_json:    data.to_json
        }.merge!(locals)
        
        # {block_content:rendered_block, vue_sfc:{name:name, vue_template:template, vue_script:script}}
        #rendered_root_sfc_js = \
        #app_js << (
        components_js(locals:{}, **options) << "\n" << (
          parsed_script(locals) ||
          wrapper(:root_object_js, locals:locals, **options)
        )
        
        #app_js << rendered_root_sfc_js
        
        # if minify
        #   #extra_spaces_removed = app_js.gsub(/(^\s+)|(\s+)|(\s+$)/){|m| {$1 => "\\\n", $2 => ' ', $3 => "\\\n"}[m]}
        #   Uglifier.compile(app_js, harmony:true).gsub(/\s{2,}/, ' ')
        # else
        #   app_js
        # end
        #app_js << "; App = VueApp;"
      end  # compile_app_js
      
    end  # VueRoot
  end # Helpers
end # Vue

