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
# See Ruby 2.4 release notes & changelog for more info on the refinement features used here:
# https://github.com/ruby/ruby/blob/v2_4_0/NEWS
#
module Vue
  module Helpers
    module Methods
    end
    
    module HelperRefinements
      
      refine Methods do
        
        # This has to be here, NOT above under HelperRefinements.
        using CoreRefinements
        
        # TODO: Do we need this: 'ERB::Util.html_escape string'. It will convert all html tags like this: "Hi I&#39;m some text. 2 &lt; 3".
        def render_ruby_template(template_text_or_file, locals:{}, template_engine:nil)
          #puts "RENDER_ruby_template(\"#{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}\", locals:#{locals}, template_engine:#{template_engine}), Tilt.current_tempate: '#{Tilt.current_template}'"
          
          tilt_template = load_template(template_text_or_file, template_engine:nil)
        
          rslt = if tilt_template.is_a?(Tilt::Template)
            tilt_template.render(self, **locals)
          else
            tilt_template
          end
          
          #puts "RENDER_ruby_template '#{tilt_template}' result: #{rslt}"
          puts "  Rendered #{template_text_or_file.inspect[0..24]} with: #{tilt_template}" if rslt
          rslt
        end
        
        def load_template(template_text_or_file, template_engine:nil)
          case template_text_or_file
          when Tilt::Template
            template_text_or_file
          when Symbol
            path = template_path(template_text_or_file, template_engine:template_engine)
            #puts "RENDER_ruby_template path-if-symbol: #{path}"
            if File.file?(path.to_s)
              Tilt.new(path, 1, outvar: Vue::Helpers.vue_outvar)
            else
              # TODO: This should be logger.debug
              #puts "RENDER_ruby_template template-missing: #{template_text_or_file}"
            end           
          when String
            Tilt.template_for(template_engine || current_template_engine).new(nil, 1, outvar: Vue::Helpers.vue_outvar){template_text_or_file}
          end
        rescue
          # TODO: Make this a logger.debug output.
          puts "Render_ruby_template error building tilt template for #{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}...: #{$!}"
          #puts "BACKTRACE:"
          #puts $!.backtrace
          nil
        end
        
        # Returns nil instead of default if no current engine.
        def current_template_engine
          #current_engine || Vue::Helpers.template_engine
          Tilt.default_mapping.template_map.invert[Tilt.current_template.class]  #|| Vue::Helpers.template_engine
        end
        
        # TODO: Decide how we want to determine template-engine suffix.
        # Search for all possible suffixes? Search for only the given template_engine? Something else?
        def template_path(name, template_engine:nil)   #current_template_engine)
          template_engine ||= '*'
          #tp = File.join(Dir.getwd, Vue::Helpers.views_path, "#{name.to_s}.vue.#{template_engine}")
          #puts "Template_path generated for '#{name}': #{tp}"
          #tp
          #puts "TEMPLATE_path searching with name: #{name}, template_engine: #{template_engine}"
          ([Vue::Helpers.views_path].flatten.uniq.compact || Dir.getwd).each do |start_path|
            #puts "TEMPLATE_path searching views-path: #{start_path}"
            Dir.breadth_first("*", base:start_path) do |path|
              #puts "TEMPLATE_path inspecting file: #{path}"
              return path if File.fnmatch(File.join('*', "#{name}.vue.#{template_engine}"), path)
              return path if File.fnmatch(File.join('*', "#{name}.vue"), path)
              return path if File.fnmatch(File.join('*', name.to_s), path)
            end
          end

          return nil
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
          #puts "CAPTURE_HTML args: #{args}, root_name: #{root_name}, buffer_name:#{buffer_name}, locals:#{locals}"
          return unless block_given?
          current_template = current_template_engine || Vue::Helpers.template_engine
          #puts "CAPTURE_HTML current_template: #{current_template}."
          case current_template.to_s
          when /erb/
            #puts "Capturing ERB block."
            return(capture(*args, &block)) if respond_to?(:capture)
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
          return(text) if respond_to?(:capture)
          current_template = current_template_engine || Vue::Helpers.template_engine
          #puts "CONCAT_CONTENT current_template_engine: #{current_template_engine}."
          case current_template.to_s
          when /erb/ 
            buffer(buffer_name) << text
          when /haml/
            haml_concat(text)
          else
            text
          end
        end
        
        # TODO: This should be a Vue::Helpers or Utilities module method.
        def secure_key
          SecureRandom.urlsafe_base64(32)
        end
        
      end # refine Methods
      
    end # HelperRefinements
    
    using HelperRefinements
    
  end # Helpers
end # Vue

