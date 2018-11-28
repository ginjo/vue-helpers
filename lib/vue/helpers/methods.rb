require 'securerandom'
require 'tilt'
require 'erb'

require_relative 'utilities'
require_relative 'vue_root'

module Vue
  module Helpers
    using Refinements
    
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
    self.root_object_js = 'var #{app_name} = new Vue({el: ("##{root_name}"), data: #{vue_data_json}})'
    self.template_engine = :erb
    self.views_path = 'app/views'
    self.vue_outvar = '@_vue_outvar'
    
  
    # Include this module in your controller (or action, or routes, or whatever).
    module Methods
    
      def self.included(other)
        other.send(:prepend, ControllerPrepend)
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
        
        compiled_component_js = compile_component_js(name, *component_content_ary)
        #puts "VC #{name} compiled_component_js: #{compiled_component_js}"
        
        vue_roots(root_name).components[name] = compiled_component_js
        
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
      def vue_root_inline(root_name = Vue::Helpers.root_name)
        #puts "VUE: #{vue}"
        return unless compiled = compile_vue_output(root_name)
        interpolated_wrapper = Vue::Helpers.inline_js_wrapper_html.interpolate(compiled: compiled)
      end
  
      # Outputs html script block with src pointing to tmp file on server.
      def vue_root_external(root_name = Vue::Helpers.root_name)
        return unless compiled = compile_vue_output(root_name)
        key = secure_key
        callback_prefix = Vue::Helpers.callback_prefix
        Vue::Helpers.cache_store[key] = compiled
        interpolated_wrapper = Vue::Helpers.external_js_wrapper_html.interpolate(callback_prefix: callback_prefix, key: key)
      end
      
      def vue_root(root_name = Vue::Helpers.root_name, external_resource:false, **options, &block)
        block_result = capture_html(&block) if block_given?
        
        root_script_output = case external_resource
        when true; vue_root_external(root_name)
        when String; vue_root_external(root_name)
        else vue_root_inline(root_name)
        end
        
        if block_result
          concat_content(Vue::Helpers.root_app_wrapper_html.interpolate(
            # locals
            root_name:root_name,
            block_result:block_result,
            root_script_output:root_script_output
          ))
        else
          root_output
        end
      end
      

      
      private
      ### TODO: Should these be refinements, since they may interfere with other app or controller methods?
      
      # Stores all root apps defined by vue-helpers, plus their compiled components.
      def vue_roots(root_name = Vue::Helpers.root_name)
        @vue_roots ||= {}
        @vue_roots[root_name.to_s] ||= RootApp.new
      end
      
      # Renders block of ruby template code.
      # Returns string.
      def render_block(locals:{}, template_engine:current_template_engine, &block)
        block_content = capture_html(*locals, &block) if block_given?
        #puts "render_block captured block: #{block_content}"
        block_content
      end
      
      # Renders and parses sfc file.
      # Returns result from parse_sfc_file.
      def render_sfc_file(file_name:nil, locals:{}, template_engine:current_template_engine)
        rendered_vue_file = render_ruby_template(file_name.to_sym, locals:locals, template_engine:template_engine)
        #puts "RENDERED_vue_file for '#{file_name}': #{rendered_vue_file}"
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
        el_name = tag || name
        if tag
          attributes['is'] = name
        end
              
        # Compiles attributes string from given ruby hash.
        attributes_string = attributes.inject(''){|o, kv| o.to_s << "#{kv[0]}=\"#{kv[1]}\" "}      
        
        rendered_component_block_template = Vue::Helpers.component_wrapper_html.interpolate(**
          {
            name:name,
            tag:tag,
            el_name:el_name,
            block_content:block_content,
            attributes_string:attributes_string
          }.merge(locals)
        ).to_s
      end
  
      #def compile_component_js(name, template, script)
      def compile_component_js(name, vue_template=nil, vue_script=nil)
        if vue_script
          # Yes, this looks weird, but remember we're just replacing the beginning of the script block.
          vue_script.gsub!(/export\s+default\s*\{/, "Vue.component('#{name}', {template: `#{vue_template}`,") << ")"
        end
      end
  
      def compile_vue_output(root_name = Vue::Helpers.root_name,
          file_name:root_name,
          app_name:root_name.camelize,
          template_engine:current_template_engine,
          &block
        )
        
        vue_output = ""
        
        components = vue_roots(root_name).components
        if components.is_a?(Hash) && components.size > 0 && values=components.values
          vue_output << values.join(";\n")
          vue_output << ";\n"
        else
          return
        end
        
        locals = {
          root_name:        root_name,
          app_name:         app_name,
          file_name:        file_name,
          template_engine:  template_engine,
          vue_data_json:    vue_roots(root_name).data.to_json
        }
        
        # {block_content:block_content, vue_sfc:{name:name, vue_template:template, vue_script:script}}
        rendered_sfc_script = \
          render_sfc_file(file_name:file_name.to_sym, locals:locals, template_engine:template_engine).to_a[1] ||
          Vue::Helpers.root_object_js.interpolate(**locals)
        
        vue_output << rendered_sfc_script
        vue_output << "; App = VueApp;"
      end  # compile_vue_output
          
      def secure_key
        SecureRandom.urlsafe_base64(32)
      end
      
      def current_template_engine
        #current_engine || Vue::Helpers.template_engine
        Tilt.default_mapping.template_map.invert[Tilt.current_template.class] || Vue::Helpers.template_engine
      end
      
      def template_path(name, template_engine:current_template_engine)
        tp = File.join(Dir.getwd, Vue::Helpers.views_path, "#{name.to_s}.vue.#{template_engine}")
        #puts "Template_path generated for '#{name}': #{tp}"
        tp
      end
      
      # Capture & Concat
      # See https://gist.github.com/seanami/496702
      # TODO: This needs to handle haml & slim as well.
      
      def buffer(buffer_name = nil)
        #@_out_buf
        buffer_name ||= Tilt.current_template.instance_variable_get('@outvar') || @outvar || Vue::Helpers.default_outvar
        #puts "BUFFER chosen: #{buffer_name}, ivars: #{instance_variables}"
        instance_variable_get(buffer_name) ||
        instance_variable_set(buffer_name, '')
      end
      
      def capture_html(*args, buffer_name:nil, &block)
        return unless block_given?
        #puts "CAPTURE_HTML current_template_engine: #{current_template_engine}."
        case current_template_engine.to_s
        when /erb/
          #puts "Capturing ERB block."
          pos = buffer(buffer_name).size
          yield(*args)
          #puts "Capture_html block.call result: #{r}"
          buffer(buffer_name).slice!(pos..buffer(buffer_name).size)
        when /haml/
          #puts "Capturing HAML block."
          capture_haml(*args, &block)
        else
          #puts "Capturing generic template block."
          yield(*args)
        end
      end
      
      def concat_content(text='', buffer_name:nil)
        #puts "CONCAT_CONTENT current_template_engine: #{current_template_engine}."
        case current_template_engine.to_s
        when /erb/ 
          buffer(buffer_name) << text
        when /haml/
          haml_concat(text)
        else
          text
        end
      end
      
    end # Methods
  end # Helpers
end # Vue