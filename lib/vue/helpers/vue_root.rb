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
        external_resource:  nil,
        template_literal:   nil,
        minify:             nil,
        locals:             {},
      }
      
      attr_accessor *defaults.keys
      
      ###  Under Construction
      # Renders the html block to replace ruby vue_app tags.
      #def render(tag_name=nil, locals:{}, attributes:{}, &block) # From vue_component
      def render(_root_name=root_name, _locals:locals, **options, &block)
        
        block_content = context.capture_html(root_name:_root_name, locals:_locals, **options, &block) if block_given?
        
        wrapper(:component_call_html, locals:_locals,
          name:_root_name,
          el_name:(_root_name).to_s.kebabize,
          block_content:block_content.to_s,
          attributes_string:attributes.to_html_attributes
        )
      end
            
      # Gets or creates a related component.
      def component(_name, **options)
        repo.component(_name, **options.merge({root_name:(name || root_name)}))
      end
      
      # Selects all related components.
      def components
        repo.select{|k,v| v.type == 'component' && v.root_name == name}.values
      end
      
      # Returns JS string of all component object definitions.
      def components_js(**options)
        puts "VueRoot#componenets_js called with components: #{components.map(&:name)}"
        components.map{|c| c.to_component_js(**options)}.join("\n")
      end
      
      # Returns HTML string of component vue templates in x-template format.
      def components_x_template
        components.map{|c| c.get_x_template}.join("\n")
      end      
      
      # Compiles js output for entire vue-app for this root object.
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
                
        #app_js = ''
        
        #components = vue_object_list.collect(){|k,v| v if v.type == 'component' && v.root_name == name}.compact
        
        # if components.size > 0
        #   components.each do |cmp|
        #     app_js << cmp.to_component_js
        #     app_js << ";\n"
        #   end            
        # else
        #   return
        # end
        
        locals = {
          root_name:        name.to_s.kebabize,
          app_name:         (options[:app_name] || js_var_name),
          file_name:        file_name,
          template_engine:  template_engine,
          #components:       (components.keys.map{|k| k.to_s.camelize}.join(', ') if register_local),
          components:       components.map{|c| c.js_var_name}.join(', '),
          vue_data_json:    data.to_json
        }.merge!(locals)
        
        # {block_content:rendered_block, vue_sfc:{name:name, vue_template:template, vue_script:script}}
        #rendered_root_sfc_js = \
        #app_js << (
        components_js(locals:{}, **options) << "\n" << (
          #render_sfc_file(file_name:file_name.to_sym, template_engine:template_engine, locals:locals).to_a[1] ||
          parsed_script(locals) ||
          wrapper(:root_object_js, locals:locals, **options)
          #Vue::Helpers.root_object_js.interpolate(**locals)
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

