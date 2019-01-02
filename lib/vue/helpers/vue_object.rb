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
        #locals:          {},
        
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
      
      # Creates custom attr readers that tie in to defaults.
      def self.custom_attr_reader(*args)
        args.each do |a|
          define_method(a) do |use_default=true|
            get_attribute(a, use_default)
          end
        end
      end
      
      #attr_accessor :repo, *defaults.keys
      attr_reader   :initialized
      
      
      ### Internal methods
      
      def defaults
        self.class.defaults
      end
      
      # For debugging.
      def print_ivars
        puts "\nIVARS:"
        instance_variables.each do |v|
          unless v.to_s[/repo/i]
            puts "#{v}: #{instance_variable_get(v)}"
          end
        end
      end
      
      def initialize(name, **options)
        @name = name
        #puts "VueObject created: #{name}, self: #{self}"
        initialize_options(**options)
      end
      
      def initialize_options(**options)
        @repo ||= options.delete(:repo)
        #locals = options.delete(:locals) || {}
        #puts "\n#{self.class.name}.initialize_options '#{name}' #{options.inspect}"
        return self unless options.size > 0 && !@initialized
        locals = options.delete(:locals) || {}
        #puts "\n#{self.class.name}.initialize_options '#{name}', #{options.inspect}, locals:#{locals.inspect}"

        merged_options = defaults.dup.merge(options)
        
        # Sets each default ivar, unless ivar is already non-nil.
        merged_options.each do |k,v|
          #puts "Setting ivar '#{k}' with '#{v}', was previously '#{instance_variable_get('@' + k.to_s)}'"
          #instance_variable_set("@#{k}", v) if v && instance_variable_get("@#{k}").nil?  #!(v.respond_to?(:empty) && v.empty?)
          instance_variable_set("@#{k}", v) if instance_variable_get("@#{k}").nil?
        end
        
        @file_name ||= @name
        
        #load_dot_vue if file_name
        load_tilt_template if file_name   #&& !tilt_template
        
        # We need this to discover subcomponents, otherwise
        # vue_app won't know about them until it's too late.
        render_template(**locals)
        
        #puts "\n#{self.class.name} initialized."
        #print_ivars
        
        @initialized = true
        #puts "VueObject initialized options: #{name}, self: #{self}"
        self
      end
      
      # Loads a dot-vue into a tilt template, but doesn't render or parse it.
      def load_tilt_template
        self.tilt_template = context.load_template(file_name.to_sym, template_engine:template_engine(false))
      end
      
      # Renders loaded tilt_template.
      # TODO: Find a way to easily insert attributes like 'name', 'root_name', etc. into locals.
      #   Or just insert the current vue object instance into the locals
      def render_template(**locals)
        @rendered_template ||= (
          #puts "\n#{self.class.name} '#{name}' calling render_template with tilt_template: #{tilt_template&.file}, engine: #{template_engine}, locals: #{locals}"
          context.render_ruby_template(tilt_template, template_engine:template_engine(false), locals:locals.merge(vo:self, vue_object:self)) if !tilt_template.to_s.empty?
        )
      end
      
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
      def wrapper(wrapper_name, **locals)   #, **wrapper_options)
        #Vue::Helpers.send(wrapper_name).interpolate(**wrapper_options.merge(locals))
        Vue::Helpers.send(wrapper_name).interpolate(locals)
      end
      
      def js_var_name
        name.to_s.camelize
      end
      
      # def is_set?(setting)
      #   case
      #     when !send(setting).nil?; send(setting)
      #     when !root.send(setting).nil?; root.send(setting)
      #     when !Vue::Helpers.send(setting).nil?; Vue::Helpers.send(setting)
      #   end
      # end
      
      # Get attribute, considering upstream possibilities.
      def get_attribute(attribute, use_default=true)
        case
          when
            ( val = instance_variable_get("@#{attribute}"); !val.nil? );
            val
          when
            type != 'root' &&
            root.respond_to?(attribute) &&
            ( val = root.send(attribute, use_default); !val.nil? );
            val
          when
            use_default &&
            Vue::Helpers.respond_to?(attribute) &&
            ( val = Vue::Helpers.send(attribute); !val.nil? );
            val
        end
      end
    
    end # VueObject
  end # Helpers
end # Vue

