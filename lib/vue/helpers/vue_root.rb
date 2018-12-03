require_relative 'utilities'
require_relative 'helper_refinements'

module Vue

  Debug = {}

  module Helpers
    using CoreRefinements
    using HelperRefinements
  
    # # Instance represents a single vue root app and all of its components.
    # class RootApp
    #   attr_accessor :components, :data
    # 
    #   def initialize(*args, **opts)
    #     @components = opts[:components] || {}
    #     @data       = opts[:data] || {}
    #   end
    # end
    
    # Always use the repository interface for vue-object crud operations.
    class VueRepository < Hash
      attr_reader :context
      
      def initialize(context)
        @context = context
      end
    
      def get_or_create(klas, name, **options)
        obj = fetch(name){|n| self[name] = klas.new(name, **options.merge({repo:self}))}
        obj.repo ||= self
        obj.initialize_options(**options) unless obj.initialized
        obj
      end
      
      def root(*args)
        get_or_create(VueRoot, *args)
      end
      alias_method :[], :root
      
      def component(*args)
        get_or_create(VueComponent, *args)
      end
    end
    
    # TODO: Consider this as a base for VueRoot and VueComponent classes.
    #
    # TODO: Yikes!!! Vue components can be called MULTIPLE times,
    # so we can't store the calling args OR the block here.
    # Also, we can't pass locals to the dot-vue file, since there is
    # only ONE of them per request, per component-name.
    # Locals are handled by Vue itself in the browser.
    #
    # If the user passed locals to the rendering call in the controller,
    # do we need to pass those locals down the chain?
    # To the dot-vue file?
    # To the block-capture?
    #
    # But note that Vue root-apps can only be called once,
    # so should we continue to store the vue-app calling args & block here,
    # or pass them in at run-time as well? I think it ALL has to be dynamic.
    #
    # So note that most of the commented-out options here will need to be
    # methods on the VueObject.
    #
    class VueObject
      DEFAULTS = {
        # Only what's necessary to load dot-vue file.
        name:             nil,
        root_name:        nil,
        file_name:        nil,
        template_engine:  nil,
        #context:          nil,
        
        # Vue-specific options for browser processing.
        # TODO: We can accept :data, :components, and other vue-spepcific options,
        # but multiple calls will only respect the last (or first?) one.
        # ... Unless we create a fancy method to merge vue-component options.
        data:             {},
        #components:       [], I don't think we need this here, it's covered by a method.
        watch:            {},
                
        # These I think we can still store, since they shouldn't change throughout a single request.
        rendered_dot_vue: nil,
        parsed_template:  nil,
        parsed_script:    nil,
        
        # Utility
        repo:             nil
      }
      
      attr_accessor *DEFAULTS.keys
      attr_reader   :initialized
      
      
      ### Internal methods
      
      def initialize(name, **options)
        @name = name
        Debug[name] = self
        #puts "VueObject created: #{name}, self: #{self}"
        initialize_options(**options)
      end
      
      def initialize_options(**options)
        return self unless options.size > 0 && !@initialized
        # This is experimental, just to see if this works here away from the controller instance.
        #@template_engine = Tilt.current_template

        merged_options = DEFAULTS.dup.merge(options)
        merged_options.each do |k,v|
          instance_variable_set("@#{k}", v) if v
        end
        
        # TODO: Do this (handle dynamic defaults) for other parameters too, like file_name, app_name, etc.
        if context
          @template_engine ||= context.current_template_engine
          #vue_object_list[name] = self
        end
        
        load_dot_vue if file_name
        
        @initialized = true
        #puts "VueObject initialized options: #{name}, self: #{self}"
        self
      end

      # Renders and parses sfc file.
      # Used to be 'render_sfc_file'
      def load_dot_vue
        self.rendered_dot_vue = context.render_ruby_template(file_name.to_sym, template_engine:template_engine)
        parse_vue_sfc(rendered_dot_vue.to_s)
      end
      
      # Parses a rendered sfc file.
      # Returns [nil, template-as-html, nil, script-as-js].
      # Must be HTML (already rendered from ruby template).
      def parse_vue_sfc(template_text=rendered_dot_vue)
        a,self.parsed_template,c,self.parsed_script = template_text.to_s.match(/(.*<template>(.*)<\/template>)*.*(<script>(.*)<\/script>)/m).to_a[1..-1]
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
        name.camelize
      end
    
    end # VueObject


    class VueComponent < VueObject
      def type; 'component'; end
      
      # Renders the html block to replace ruby view-template tags.
      # NOTE: Locals may be useless here.
      # TODO: Should this be in the VueComponent class?
      # Used to be 'to_html_block'
      def render(tag_name=nil, locals:{}, attributes:{}, &block)
        # Adds 'is' attribute to html vue-component element,
        # if the user specifies an alternate 'tag_name' (default tag_name is name-of-component).
        if tag_name
          attributes['is'] = name
        end
        
        wrapper(:component_call_html, locals:locals,
          name:name,
          tag_name:tag_name,
          el_name:(tag_name || name).to_s.kebabize,
          block_content:(context.capture_html(root_name:root_name, **locals, &block) if block_given?),
          attributes_string:attributes.to_html_attributes
        )
      end
  
      # Builds js output string.
      def to_component_js(register_local:Vue::Helpers.register_local, template_literal:Vue::Helpers.template_literal, **options)
          # The above **options are not used yet, but need somewhere to catch extra stuff.
          template_spec = template_literal ? "\`#{parsed_template.to_s.escape_backticks}\`" : "'##{name}-template'"
          js_output = register_local \
            ? 'var #{name} = {template: #{template_spec}, \2;'
            : 'var #{name} = Vue.component("#{name}", {template: #{template_spec}, \2);'  # ) << ")"
          
          # TODO: Make escaping backticks optional, as they could break user templates with nested backtick blocks, like ${``}.
          parsed_script.gsub( 
            /export\s+default\s*(\{|Vue.component\s*\([^\{]*\{)(.*$)/m,
            js_output
          ).interpolate(name: name.to_s.camelize, template_spec: template_spec)
      end
      
      
      def get_x_template
        wrapper(:x_template_html, name:name, template:parsed_template)
      end
    end
    
    
    class VueRoot < VueObject
      def type; 'root'; end
      
      # Creates or gets a related component
      def component(_name, **options)
        repo.component(_name, **options.merge({root_name:(name || root_name)}))
      end
      
      def components
        repo.select{|k,v| v.type == 'component' && v.root_name == name}.values
      end
      
      # JS string of all component object definitions
      def components_js(**options)
        components.map{|c| c.to_component_js(**options)}.join("\n")
      end
      
      def components_x_template
        components.map{|c| c.get_x_template}.join("\n")
      end      
      
      # Compiles js output for entire vue-app for this root object.
      def compile_app_js( **options  # generic opts placeholder until we get the args/opts flow worked out.
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
        }
        
        # {block_content:rendered_block, vue_sfc:{name:name, vue_template:template, vue_script:script}}
        #rendered_root_sfc_js = \
        #app_js << (
        components_js(**options) << "\n" << (
          #render_sfc_file(file_name:file_name.to_sym, template_engine:template_engine, locals:locals).to_a[1] ||
          parsed_script ||
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