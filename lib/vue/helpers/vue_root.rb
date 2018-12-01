require_relative 'utilities'
require_relative 'helper_refinements'

module Vue
  module Helpers
    using CoreRefinements
    using HelperRefinements
  
    # Instance represents a single vue root app and all of its components.
    class RootApp
      attr_accessor :components, :data
  
      def initialize(*args, **opts)
        @components = opts[:components] || {}
        @data       = opts[:data] || {}
      end
    end
    
    # TODO: Consider this as a base for VueRoot and VueComponent classes.
    # The @vue_root hash would still keep all of these at a flat level, keyed by unique name.
    class VueObject
      DEFAULTS = {
        name:          nil,
        root_name:     nil,
        file_name:     nil,
        attributes:    nil,
        raw_dot_vue:   nil,
        html_template: nil,
        js_object:     nil,
        data:          {},
        # Should eventually be an array, just like in js object.
        components: {}
      }
      
      attr_accessor :original_options, *DEFAULTS.keys
      
      def initialize(name, **options)
        @name = name
        @original_options = DEFAULTS.dup.merge(options)
        @original_options.each do |k,v|
          instance_variable_set("@#{k}", v) if v
        end
        puts "VueObject created: #{name}, self: #{self}"
      end
      
      # Renders and parses sfc file.
      # Returns result from parse_sfc_file.
      def render_sfc_file(file_name:nil, locals:{}, template_engine:current_template_engine)
        rendered_vue_file = render_ruby_template(file_name.to_sym, template_engine:template_engine, locals:locals)
        parse_vue_sfc(rendered_vue_file.to_s)
      end
      
      # Parses a rendered sfc file.
      # Returns [template-as-html, script-as-js].
      # Must be HTML (already rendered from ruby template).
      def parse_vue_sfc(template_text_or_file)
        raw_template = begin
          case template_text_or_file
          when Symbol; File.read(template_path(template_text_or_file))
          when String; template_text_or_file
          end
        rescue
          # TODO: Make this a logger.debug output.
          #puts "Parse_vue_sfc error getting template file: #{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}...: #{$!}"
          nil
        end
        a,template,c,script = raw_template.to_s.match(/(.*<template>(.*)<\/template>)*.*(<script>(.*)<\/script>)/m).to_a[1..-1]
        #{vue_template:template, vue_script:script}
        [template, script]
      end
      
      # TODO: Do we need this: 'ERB::Util.html_escape string'. It will convert all html tags like this: "Hi I&#39;m some text. 2 &lt; 3".
      def render_ruby_template(template_text_or_file, locals:{}, template_engine:current_template_engine)
        #puts "RENDER_ruby_template(\"#{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}\", locals:<locals>, template_engine:#{template_engine})"
          
        tilt_template = begin
          case template_text_or_file
          when Symbol; Tilt.new(template_path(template_text_or_file, template_engine:template_engine), 1, outvar: Vue::Helpers.vue_outvar)
          when String; Tilt.template_for(template_engine).new(nil, 1, outvar: Vue::Helpers.vue_outvar){template_text_or_file}
          end
        rescue
          # TODO: Make this a logger.debug output.
          #puts "Render_ruby_template error building tilt template for #{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}...: #{$!}"
          nil
        end

        tilt_template.render(self, **locals) if tilt_template.is_a?(Tilt::Template)
      end

      def compile_component_html_block(name:nil, tag:nil, attributes:{}, block_content:'', locals:{})
        
        # Adds 'is' attribute to html vue-component element,
        # if the user specifies an alternate 'tag' (default tag is name-of-component).
        if tag
          attributes['is'] = name
        end

        wrapper(:component_call_html, locals:locals,
          name:name,
          tag:tag,
          el_name:(tag || name).to_s.kebabize,
          block_content:block_content,
          attributes_string:attributes.to_html_attributes
        )
      end
  
      # Build js string given compiled/parsed vue_template and vue_script strings.
      # TODO: Consider allowing a generic component script if none provided.
      # Note that these keyword args are all required.
      def compile_component_js(name: , vue_template: , vue_script: , **options)
          js_template = options[:register_local] \
            ? 'var #{name} = {template: `#{vue_template}`, \2'
            : 'var #{name} = Vue.component("#{name}", {template: `#{vue_template}`, \2)'  # ) << ")"
          
          # TODO: Make escaping backticks optional, as they could break user templates with nested backtick blocks, like ${``}.
          vue_script.gsub(/export\s+default\s*(\{|Vue.component\s*\([^\{]*\{)(.*$)/m,
            js_template)
            .interpolate(name: name.to_s.camelize, vue_template: vue_template.to_s.escape_backticks)
      end
  
      def compile_vue_output(root_name = Vue::Helpers.root_name,
          file_name:root_name,
          app_name:root_name.camelize,
          template_engine:current_template_engine,
          register_local: Vue::Helpers.register_local,
          minify: Vue::Helpers.minify,
          # Block may not be needed here, it's handled in 'vue_app'.
          &block
        )
        
        vue_output = ""
        
        components = vue_root(root_name).components
        if components.is_a?(Hash) && components.size > 0 && values=components.values
          #vue_output << values.join(";\n")
          values.each do |cmp_hash|
            vue_output << compile_component_js(**cmp_hash, register_local:register_local)
            vue_output << ";\n"
          end            
          vue_output << ";\n"
        else
          return
        end
        
        locals = {
          root_name:        root_name.to_s.kebabize,
          app_name:         app_name,
          file_name:        file_name,
          template_engine:  template_engine,
          components:       (components.keys.map{|k| k.to_s.camelize}.join(', ') if register_local),
          vue_data_json:    vue_root(root_name).data.to_json
        }
        
        # {block_content:block_content, vue_sfc:{name:name, vue_template:template, vue_script:script}}
        rendered_root_sfc_js = \
          render_sfc_file(file_name:file_name.to_sym, template_engine:template_engine, locals:locals).to_a[1] ||
          Vue::Helpers.root_object_js.interpolate(**locals)
        
        vue_output << rendered_root_sfc_js
        
        if minify
          #extra_spaces_removed = vue_output.gsub(/(^\s+)|(\s+)|(\s+$)/){|m| {$1 => "\\\n", $2 => ' ', $3 => "\\\n"}[m]}
          Uglifier.compile(vue_output, harmony:true).gsub(/\s{2,}/, ' ')
        else
          vue_output
        end
        #vue_output << "; App = VueApp;"
      end  # compile_vue_output
      
      
      def wrapper(wrapper_name, locals:{}, **options)
        Vue::Helpers.send(wrapper_name).interpolate(**options.merge(locals))
      end
          
      def secure_key
        SecureRandom.urlsafe_base64(32)
      end



    
    end # VueObject
    
  end # Helpers
end # Vue