require 'tilt'
require 'erb'

require_relative 'helper_refinements'
require_relative 'utilities'
require_relative 'vue_repository'

module Vue
  module Helpers
    using CoreRefinements
    using HelperRefinements
    
    # Include this module in your controller (or action, or routes, or whatever).
    #
    # SEE helper_refinements.rb for the helpers supporting methods!
    #
    module Methods
    
      def self.included(other)
        other.send(:prepend, ControllerPrepend)
      end

      def vue_repository
        @vue_repository ||= VueRepository.new(context=self)
        #puts "Getting vue_repository #{@vue_repository.class} with keys: #{@vue_repository.keys}"
        @vue_repository
      end
      
      def vue_root(root_name = Vue::Helpers.root_name, **options)
        # @vue_root ||= {}
        # @vue_root[root_name] ||= VueRoot.new(root_name)
        vue_repository.root(root_name, **options)
      end
  
      # Inserts Vue component-call block in html template.
      # Name & file_name refer to file-name.vue.<template_engine> SFC file. Example: products.vue.erb.
      def vue_component(name,
          root_name:Vue::Helpers.root_name,
          attributes:{},
          tag_name:nil,
          file_name:nil,
          locals:{},
          template_engine:nil,
          
          # TODO: Should the catchall be this? or some other kind of option set?
          **attitional_attributes,
          &block
        )
        
        puts "\nVue_component '#{name}' with args '#{local_variables.inject({}){ |c, i| c[i.to_s] = eval(i.to_s); c }}'"
        
        # This should only pass args that are necessary to build the base object.
        # Tag-name and attributes are not relevant here.
        component = vue_root(root_name).component(name,
          root_name:        root_name,
          file_name:        file_name,
          template_engine:  template_engine,
          locals:           locals
        )
        
        # Renders the per-call html block.
        # Pass tag_name, attributes, locals, and block.
        component_output = component.render(tag_name, attributes:attributes.merge(attitional_attributes), locals:locals, &block)
        
        # Concat the content if block given, otherwise just return the content.
        if block_given?
          #puts "Vue_component concating content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
          concat_content(component_output)
        else
          #puts "Vue_component returning content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
          return component_output
        end
      end  # vue_component


      # Inserts Vue app-call block in html template.
      # Builds vue html and js for return to browser.
      # TODO: Can some of these params be moved downstream into the VueRoot instance?
      #   Or can some of these be passed through **options downstream, like 'register_local'?
      #   Note that you don't see it mentioned in this method. Should it be here?
      #
      # Returns (or concats if block given) rendered html and js.
      def vue_app(root_name = Vue::Helpers.root_name,
          external_resource:  Vue::Helpers.external_resource,
          template_literal:   Vue::Helpers.template_literal,
          minify:             Vue::Helpers.minify,
          locals:             {},
          **options,
          &block
        )
        
        puts "\nVue_app '#{root_name}' with args '#{local_variables.inject({}) { |c, i| c[i.to_s] = eval(i.to_s); c }}'"
        
        options.merge!(
          template_literal: template_literal,
          external_resource: external_resource,
          minify: minify
        )
        
        root_app = vue_root(root_name, locals:locals, **options)
        
        root_output = root_app.render(locals:locals, **options, &block)
                
        if block_given?
          concat_content(root_output)
        else
          root_output
        end
      end

      
    end # Methods
  end # Helpers
end # Vue