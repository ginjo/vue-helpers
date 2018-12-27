require_relative 'utilities'
require_relative 'helper_refinements'
require_relative 'vue_object'

module Vue
  module Helpers
    using CoreRefinements
    using HelperRefinements

    class VueComponent < VueObject
      def type; 'component'; end
      
      #puts "VueComponent defining @defaults"
      @defaults = {
        root_name:         Vue::Helpers.root_name,
        register_local:    nil,
        template_literal:  nil
      }
      
      attr_writer *defaults.keys
      custom_attr_reader *defaults.keys
      
      # Gets root object
      def root
        repo.root(root_name)
      end
      
      # Renders the html block to replace ruby vue_component tags.
      # TODO: Are locals used here? Do they work?
      def render(tag_name=nil, locals:{}, attributes:{}, &block)
        # Adds 'is' attribute to html vue-component element,
        # if the user specifies an alternate 'tag_name' (default tag_name is name-of-component).
        if tag_name
          attributes['is'] = name
        end
        
        block_content = context.capture_html(root_name:root_name, locals:locals, &block) if block_given?
        
        # TODO: Are locals being passed properly here?
        wrapper(:component_call_html,
          name:name,
          tag_name:tag_name,
          el_name:(tag_name || name).to_s.kebabize,
          block_content:block_content.to_s,
          attributes_string:attributes.to_html_attributes,
          **locals
        )
      end
  
      # Builds js output string.
      # TODO: Follow this backwards/upstream to determine if parsed_template, parsed_script, and locals are being handled correctly.
      #def to_component_js(register_local:Vue::Helpers.register_local, template_literal:Vue::Helpers.template_literal, locals:{})  #, **options)
      def to_component_js(locals:{})
          # The above **options are not used yet, but need somewhere to catch extra stuff.
          template_spec = template_literal ? "\`#{parsed_template(locals).to_s.escape_backticks}\`" : "'##{name}-template'"
          js_output = register_local \
            ? 'var #{name} = {template: #{template_spec}, \2;'
            : 'var #{name} = Vue.component("#{name}", {template: #{template_spec}, \2);'  # ) << ")"
          
          # TODO: Make escaping backticks optional, as they could break user templates with nested backtick blocks, like ${``}.
          _parsed_script = parsed_script(locals)
          _parsed_script.gsub( 
            /export\s+default\s*(\{|Vue.component\s*\([^\{]*\{)(.*$)/m,
            js_output
          ).interpolate(name: name.to_s.camelize, template_spec: template_spec) if _parsed_script
      end
      
      # TODO: Follow this backwards/upstream to determine if parsed_template, parsed_script, and locals are being handled correctly.
      def get_x_template(**locals)
        wrapper(:x_template_html, name:name, template:parsed_template(locals), **locals)
      end
      
      # def template_literal?
      #   case
      #     when !template_literal.nil?; template_literal
      #     when !root.template_literal.nil?; root.template_literal
      #     when !Vue::Helpers.template_literal.nil?; Vue::Helpers.template_literal
      #   end
      # end
      
    end # VueComponent
  end # Helpers
end # Vue

