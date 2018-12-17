require_relative 'utilities'
require_relative 'helper_refinements'

module Vue

  Debug = []

  module Helpers
    using CoreRefinements
    using HelperRefinements
  
    # Stores ruby representations of vue objects.
    # Intended for a single request cycle.
    # TODO: Rename this to VueStash.
    # NOTE: Always use the repository interface for vue-object crud operations from controller or views.
    class VueRepository < Hash
      attr_reader :context
      
      # Always pass a context when creating a VueRepository.
      def initialize(context)
        Debug << self
        @context = context
      end
    
      # Master get_or_create for any object in the repository.
      def get_or_create(klas, name, **options)
        obj = fetch(name){|n| self[name] = klas.new(name, **options.merge({repo:self}))}
        obj.repo ||= self
        obj.initialize_options(**options) unless obj.initialized
        obj
      end
      
      # Gets or creates a VueRoot instance.
      def root(name, **options)
        get_or_create(VueRoot, name, **options)
      end
      alias_method :[], :root
      
      # Gets or creates a VueComponent instance.
      def component(name, **options)
        get_or_create(VueComponent, name, **options)
      end
    end
    
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
        locals:           {},
        
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
      
      def initialize_options(**options)
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


    class VueComponent < VueObject
      def type; 'component'; end
      
      # Renders the html block to replace ruby vue_component tags.
      # TODO: Are locals used here? Do they work?
      def render(tag_name=nil, locals:{}, attributes:{}, &block)
        # Adds 'is' attribute to html vue-component element,
        # if the user specifies an alternate 'tag_name' (default tag_name is name-of-component).
        if tag_name
          attributes['is'] = name
        end
        
        block_content = context.capture_html(root_name:root_name, **locals, &block) if block_given?
        
        wrapper(:component_call_html, locals:locals,
          name:name,
          tag_name:tag_name,
          el_name:(tag_name || name).to_s.kebabize,
          block_content:block_content.to_s,
          attributes_string:attributes.to_html_attributes
        )
      end
  
      # Builds js output string.
      # TODO: Follow this backwards/upstream to determine if parsed_template, parsed_script, and locals are being handled correctly.
      def to_component_js(register_local:Vue::Helpers.register_local, template_literal:Vue::Helpers.template_literal, locals:{}, **options)
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
        wrapper(:x_template_html, name:name, template:parsed_template(locals))
      end
    end
    
    
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