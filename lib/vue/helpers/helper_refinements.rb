require 'uglifier'
require_relative 'utilities'

# This file contains the bulk of vue-helpers functions.
# They are constructed here as a module of refinements,
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

    # This block of methods is used as refinements in Ruby >= 2.4,
    # and is used as regular module methods (private) in Ruby < 2.4.
    # This is done to accommodate a wider range of Ruby versions,
    # since Ruby < 2.4 doesn't allow refining of Modules.
    # See if-then block below.
    #
    MethodsBlock = Proc.new do
      
      # This has to be here, NOT above under HelperRefinements.
      using CoreRefinements
      
      # Can't be private, since VueObject instances call these methods.
      #private
      
      # TODO: Cleanup Load/Render template calls upstream, then cleanup these methods here.
      # These are a mess, since they were hacked together when their functionality was split up.
      def render_ruby_template(template_text_or_file, template_engine:nil, locals:{})
        #puts "  RENDERING ruby template '#{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}' with locals:#{locals}, template_engine:#{template_engine}, Tilt.current_tempate: '#{Tilt.current_template}'\n"
        
        tilt_template = load_template(template_text_or_file, template_engine:nil)
      
        rslt = if tilt_template.is_a?(Tilt::Template)
          #puts "  Rendering #{tilt_template}"
          #puts "  Rendering ruby template '#{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}...' from '#{tilt_template.file}' with locals:#{locals}, template_engine:#{template_engine}, Tilt.current_tempate: '#{Tilt.current_template}'"
          #puts "  Rendering ruby template '#{template_text_or_file}' from '#{tilt_template.file}' with locals:#{locals}, template_engine:#{template_engine}, Tilt.current_tempate: '#{Tilt.current_template}'"
          tilt_template.render(self, **locals)
        else
          #puts "  Render_ruby_template bypassing rendering for '#{template_text_or_file}', since '#{tilt_template}' is not a Tilt::Template"
          tilt_template
        end
        
        #puts "RENDER_ruby_template '#{tilt_template}' result: #{rslt}"
        rslt
      end
      
      def load_template(template_text_or_file, template_engine:nil)
        #puts "  LOADING template '#{template_text_or_file}' with engine: #{template_engine}"
        current_eoutvar = Thread.current.instance_variable_get(:@current_eoutvar)
        case template_text_or_file
        when Tilt::Template
          #puts "  Loading existing tilt template '#{template_text_or_file}' from '#{template_text_or_file.file}' with engine: #{template_engine}"
          template_text_or_file
        when Symbol
          #puts "  Loading template from symbol '#{template_text_or_file}' with engine: #{template_engine}"
          path = template_path(template_text_or_file, template_engine:template_engine)
          #puts "RENDER_ruby_template path-if-symbol: #{path}"
          if File.file?(path.to_s)
            Tilt.new(path, 1, outvar: Vue::Helpers.vue_outvar)
          else
            # TODO: This should be logger.debug
            #puts "RENDER_ruby_template template-missing: #{template_text_or_file}"
          end           
        when String
          #puts "  Loading template from string '#{template_text_or_file}' with engine: #{template_engine}"
          Tilt.template_for(template_engine || current_template_engine).new(nil, 1, outvar: Vue::Helpers.vue_outvar){template_text_or_file}
        end
      rescue
        # TODO: Make this a logger.debug output.
        puts "Render_ruby_template error building tilt template for #{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}...: #{$!}"
        puts "BACKTRACE:"
        puts $!.backtrace
        nil
      ensure
        Thread.current.instance_variable_set(:@current_eoutvar, current_eoutvar)
      end
      
      # Returns nil instead of default if no current engine.
      def current_template_engine(use_default=false)
        #current_engine || Vue::Helpers.template_engine
        Tilt.default_mapping.template_map.invert[Tilt.current_template.class] || (use_default && Vue::Helpers.template_engine)
      end
      
      # TODO: Decide how we want to determine template-engine suffix.
      #   Search for all possible suffixes? Search for only the given template_engine? Something else?
      #   Is this already handled here?
      def template_path(name, template_engine:nil)   #current_template_engine)
        template_engine ||= '*'
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
      # TODO: These need to handle haml & slim as well.
      
      # This appears to only be used for dev & testing.
      def get_current_eoutvar
        Thread.current.instance_variable_get(:@current_eoutvar)
      end
      
      # Returns any buffer (even if not defined).
      def buffer(buffer_name = nil)
        #@_out_buf
        buffer_name ||=
          ((ct = Tilt.current_template) && ct.instance_variable_get(:@outvar)) ||
          Thread.current.instance_variable_get(:@current_eoutvar) ||
          Vue::Helpers.default_outvar
        
        # Adds '@' to beginning of buffer_name is not exist yet.
        # Only added this to make tests pass, but not really solved yet.
        buffer_name =~ /^\@/ || buffer_name = "@#{buffer_name}"
        
        # puts "BUFFER thread-ivars: #{Thread.current.instance_variables}, thread-local-vars: #{Thread.current.send(:local_variables)}"
        # puts "BUFFER chosen: #{buffer_name}, controller/view ivars: #{instance_variables}, controller/view local-vars: #{local_variables}"
        # puts "BUFFER @outvar: #{ct.instance_variable_get(:@outvar)}"
        # puts "BUFFER @current_eoutvar: #{Thread.current.instance_variable_get(:@current_eoutvar)}"
        # puts "TILT: #{ct.instance_variables}"
        # puts "THREAD: #{Thread.current.instance_variables}"
        # puts "IVARS: #{instance_variables}"
        # puts "@_erbout: #{@_erbout}"
        
        # Unfreezes buffer value, if frozen. Don't know where this issue came from,
        # but it started in ruby 2.7. Probably burried deep in some gem dependency.
        #
        iv_val = instance_variable_get(buffer_name.to_s)
        if iv_val.frozen?
          instance_variable_set(buffer_name.to_s, iv_val.dup)
        end
        instance_variable_get(buffer_name.to_s) || ''
      end
      
      # Captures html, or whatever, from given block.
      # TODO: Probably need to pass root_name (and other options?) on to sub-components inside block.
      # Does vue even allow components in the block of a component call?
      # TODO: Are *args and locals being used?
      def capture_html(*args, root_name:Vue::Helpers.root_name, locals:{}, &block)
        #puts "CAPTURE_HTML args: #{args}, root_name: #{root_name}, locals:#{locals}"
        return unless block_given?
        
        # This is mostly for Rails. Are there other frameworks that would use this?
        return(capture(*args, &block)) if respond_to?(:capture)
        
        # This is one of the points where we finally need to know what template
        # we're using. If the actively-rendering template is not handled by Tilt,
        # we can only take a best guess. If we're wrong, the user will need to set
        # Vue::Helpers.defaults[:template_engine] to a known template type.
        current_template = current_template_engine(true)
        #puts "CAPTURE_HTML current_template: #{current_template}."
        #puts "CAPTURE_HTML block info: block-local-vars:#{block.binding.local_variables}, block-ivars:#{block.binding.eval('instance_variables')}, controller-ivars:#{instance_variables}" if block_given?
        #puts "CAPTURE_HTML block: #{block.call(*args).to_s}"
        
        # TODO: double-check & compare this section with older versions to see what
        # kind of changes were recently made (as of 2022-04-27).
        case current_template.to_s
        when /erb/i
          #puts "Capturing ERB block with eoutvar '#{get_current_eoutvar}'."
          #puts "Tilt @outvar '#{Tilt.current_template.instance_variable_get(:@outvar)}'"
          return(capture(*args, &block)) if respond_to?(:capture)
          #
          # Why was this done this way? Is it necessary?
          # I made it simpler below, but not sure if that right.
          #
          #puts "\nCapturing ERB block within #{self.class}, buffer-size: #{buffer.to_s.size}, existing_buffer: '#{buffer.to_s[24]}'"
          if buffer.to_s.size > 0
            # existing_buffer = buffer
            # pos = existing_buffer.to_s.size
            # yield(*args)
            # #block.call(*args)
            # modified_buffer = buffer
            # puts "Capturing ERB block, modified-buffer-size: #{modified_buffer.to_s.size}"
            # modified_buffer.to_s.slice!(pos..modified_buffer.to_s.size)
            buff_pos = buffer.to_s.size
            yield(*args)
            #block.call(*args)
            #puts "Capturing ERB block, modified buffer size: #{buffer.to_s.size}"
            buffer.to_s.slice!(buff_pos..buffer.to_s.size)
          else
            yield(*args)
            #block.call(*args)
          end
          #block.call(*args).to_s if block_given?
        when /haml/i
          #puts "Capturing HAML block, buffer-size: #{buffer.to_s.size}"
          capture_haml(*args, &block)
        else
          #puts "Capturing (yielding) to generic template block, buffer-size: #{buffer.to_s.size}"
          yield(*args)
          #block.call(*args)
        end
        
      end
      
      def concat_content(text='')
        return(text) if respond_to?(:capture)
        current_template = current_template_engine(true)
        # puts "CONCAT_CONTENT current_template: #{current_template}"
        # puts "CONCAT_CONTENT buffer: #{buffer}"
        case current_template.to_s
        when /erb/i
          # puts "Concating to ERB outvar '#{get_current_eoutvar}'"
          # puts "Tilt @outvar '#{Tilt.current_template.instance_variable_get(:@outvar)}'"
          # puts "RESPOND to :capture ? #{respond_to?(:capture)}"
          
          # Getting FrozenError here in ruby 2.7. See buffer() method.
          buffer.to_s << text
        when /haml/i
          haml_concat(text)
        else
          text
        end
      end
      
    end # methods_block
    
    
    if RUBY_VERSION.to_f < 2.4
      # This needs to be defined anyway, since 'refine' is called
      # in other modules/classes.
      module HelperRefinements
      end
      # Use MethodsBlock as regular Module methods if Ruby < 2.4.
      module Methods
        class_eval(&MethodsBlock)
      end
    else
      # Use MethodsBlock as Module refinements if Ruby >= 2.4.
      module HelperRefinements
        refine Methods do
          MethodsBlock.call
        end
      end # HelperRefinements
      using HelperRefinements
    end
    
  end # Helpers
end # Vue
