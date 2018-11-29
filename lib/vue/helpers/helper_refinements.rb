require_relative 'utilities'

# This file contains the bulk of vue-helpers functions.
# They constructed here as a module of refinements,
# and used in the main 'controller'. However, being refinements,
# they are invisible and inaccessible in user-space.
#
# The funky self-referencing refinement code on this page is
# necessary for these refinement methods to see each other.
# Remember... lexical scope: a refined method call must have
# 'using...' somewhere on the same page (or sometimes in the same module).
# So these refinements must refine themselves.
#
# This actually works, even with the self-refiment at the bottom of the module.
#
module Vue
  module Helpers
    module Methods
    end
    
    module HelperRefinements
      refine Methods do
        
        using CoreRefinements
        
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
              el_name:el_name.to_s.kebabize,
              block_content:block_content,
              attributes_string:attributes_string
            }.merge(locals)
          ).to_s
        end
    
        # Build js string given compiled/parsed vue_template and vue_script strings.
        # TODO: Consider allowing a generic component script if none provided.
        def compile_component_js(name, vue_template=nil, vue_script=nil, **options)
          if vue_script
            # Yes, the regex's looks weird, but remember we're just replacing the beginning of the script block.
            
            if options[:register_local]
              # Locally registered component.
              uninterpolated_string = vue_script.gsub(
                /export\s+default\s*(\{|Vue.component\s*\([^\{]*\{)/,
                'var #{name} = {template: `#{vue_template}`,'
              )
            else
              # Globally registered component.
              uninterpolated_string = vue_script.gsub(
                /export\s+default\s*\{/,
                'Vue.component("#{name}", {template: `#{vue_template}`,'
              ) << ")"
            end
            
            uninterpolated_string.interpolate(name: name.to_s.camelize, vue_template: vue_template.to_s.escape_backticks)
          end
        end
    
        def compile_vue_output(root_name = Vue::Helpers.root_name,
            file_name:root_name,
            app_name:root_name.camelize,
            template_engine:current_template_engine,
            register_local: false,
            &block
          )
          
          vue_output = ""
          
          components = vue_app(root_name).components
          if components.is_a?(Hash) && components.size > 0 && values=components.values
            vue_output << values.join(";\n")
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
            vue_data_json:    vue_app(root_name).data.to_json
          }
          
          # {block_content:block_content, vue_sfc:{name:name, vue_template:template, vue_script:script}}
          rendered_root_sfc_js = \
            render_sfc_file(file_name:file_name.to_sym, locals:locals, template_engine:template_engine).to_a[1] ||
            Vue::Helpers.root_object_js.interpolate(**locals)
          
          vue_output << rendered_root_sfc_js
          #vue_output << "; App = VueApp;"
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
          #puts "CAPTURE_HTML self: #{self}, methods: #{methods.sort.to_yaml}"
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
      
      end # refine Methods
    end # HelperRefinements

    using HelperRefinements
    
  end # Helpers
end # Vue

