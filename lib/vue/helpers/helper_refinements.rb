require 'uglifier'
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
        
        # TODO: Probbably need to pass root_name (and other options?) on to sub-components inside block.
        # Does vue even allow components in the block of a component call?
        def capture_html(*args, root_name:Vue::Helpers.root_name, buffer_name:nil, **locals, &block)
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

