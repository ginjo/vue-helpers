require_relative 'utilities'
require_relative 'helper_refinements'

module Vue
  module Helpers
    using CoreRefinements
    using HelperRefinements
  

    # NOTE: Vue components can be called MULTIPLE times,
    # so we can't store the calling args OR the block here.
    #
    # But note that Vue root-apps can only be called once,
    # so should we continue to store the vue-app calling args & block here,
    # or pass them in at run-time as well? I think it ALL has to be dynamic.
    #
    class VueObject
      
      @defaults = {
        # Only what's necessary to load dot-vue file.
        name:             nil,
        root_name:        nil,
        file_name:        nil,
        template_engine:  nil,
        #locals:           {},
        
        # The loaded (but not rendered or parsed) dot-vue file as Tilt teplate.
        # See 'initialize_options()' below
        tilt_template:    nil,
        
        # Vue-specific options to be inserted in js object.
        # Remember that component data must be a function in the js object.
        data:             {}, 
        watch:            {},
        computed:         {},
        
        # Utility
        repo:             nil
      }
      
      
      # Concatenates subclass defaults with master class defaults.
      def self.defaults
        super_defaults = superclass.singleton_class.method_defined?(__method__) ? superclass.defaults : (@defaults || {})
        super_defaults.merge(@defaults || {})
      end
      
      attr_accessor *defaults.keys
      attr_reader   :initialized
      
      
      ### Internal methods
      
      def defaults
        self.class.defaults
      end
      
      def initialize(name, **options)
        @name = name
        #puts "VueObject created: #{name}, self: #{self}"
        initialize_options(**options)
      end
      
      def initialize_options(locals:{}, **options)
        return self unless options.size > 0 && !@initialized

        merged_options = defaults.dup.merge(options)
        merged_options.each do |k,v|
          instance_variable_set("@#{k}", v) if v
        end
        
        # TODO: Do this (handle dynamic defaults) for other parameters too, like file_name, app_name, etc.
        if context
          #puts "VueObject#initialize_options '#{name}' setting @template_engine (already: '#{@template_engine}'). to context.current_template_engine: #{context.current_template_engine}"
          #puts "Tilt.current_template: #{Tilt.current_template}"
          
          @file_name ||= @name
        end
        
        #load_dot_vue if file_name
        load_tilt_template if file_name   #&& !tilt_template
        
        # We need this to discover and subcomponents, otherwise
        # vue_app won't know about them until it's too late.
        render_template(**locals)
        
        @initialized = true
        #puts "VueObject initialized options: #{name}, self: #{self}"
        self
      end

      #   # Renders and parses sfc file.
      #   # Used to be 'render_sfc_file'.
      #   # TODO: Don't render dot-vue, just load the Tilt template.
      #   def load_dot_vue(locals:{})
      #     self.rendered_dot_vue = context.render_ruby_template(file_name.to_sym, locals:locals, template_engine:template_engine)
      #     parse_vue_sfc(rendered_dot_vue.to_s)
      #   end
      
      # Loads a dot-vue into a tilt template, but doesn't render or parse it.
      def load_tilt_template
        self.tilt_template = context.load_template(file_name.to_sym, template_engine:template_engine)
      end
      
      # Renders loaded tilt_template.
      def render_template(**locals)
        @rendered_template ||= (
          puts "#{self.class} '#{name}' calling render_template with tilt_template: #{tilt_template&.file}, engine: #{template_engine}, locals: #{locals}"
          context.render_ruby_template(tilt_template, locals:locals, template_engine:template_engine)
        )
      end
      
      #   # Parses a rendered sfc file.
      #   # Returns [nil, template-as-html, nil, script-as-js].
      #   # Must be HTML (already rendered from ruby template).
      #   def parse_vue_sfc(template_text=rendered_dot_vue)
      #     a,self.parsed_template,c,self.parsed_script = template_text.to_s.match(/(.*<template>(.*)<\/template>)*.*(<script>(.*)<\/script>)/m).to_a[1..-1]
      #   end
      
      # Parses a rendered sfc file.
      # Returns [nil, template-as-html, nil, script-as-js].
      # Must be HTML (already rendered from ruby template).
      def parse_sfc(**locals)
        @parsed_sfc ||= (
          #rendered_template = render_template(**locals)
          rslt = {}
          rslt[:template], rslt[:script] = render_template(**locals).to_s.match(/(.*<template>(.*)<\/template>)*.*(<script>(.*)<\/script>)/m).to_a.values_at(2,4)
          rslt
        )
      end
      
      def parsed_template(**locals)
        @parsed_template ||= (
          parse_sfc(**locals)[:template]
        )
      end
      
      def parsed_script(**locals)
        @parsed_script ||= (
          parse_sfc(**locals)[:script]
        )
      end
      
      def context
        repo.context
      end


      ### Called from user-space by vue_root, vue_app, vue_compoenent.

      # Gets a defined wrapper, and interpolates it with the given locals & options.
      def wrapper(wrapper_name, locals:{}, **options)
        Vue::Helpers.send(wrapper_name).interpolate(**options.merge(locals))
      end
      
      def js_var_name
        name.to_s.camelize
      end
    
    end # VueObject
  end # Helpers
end # Vue

