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
      
      def vue_root(root_name=nil, **options)
        vue_repository.root(root_name, **options)
      end
  
      # Inserts Vue component-call block in html template.
      # Name & file_name refer to file-name.vue.<template_engine> SFC file. Example: products.vue.erb.
      def vue_component(name,
          root_name:nil,
          tag_name:nil,
          locals:{},
          attributes:{},
          **options,
          &block
        )
        
        #puts "\nvue_component '#{name}' with local-vars '#{local_variables.inject({}){ |c, i| c[i.to_s] = eval(i.to_s); c }}'"
        
        # This should only pass args that are necessary to build the component object.
        # Tag-name and attributes are not relevant here.
        component = vue_root(root_name).component(name, locals:locals, **options)
        
        # Renders the per-call html block.
        # Pass tag_name, attributes, locals, and block.
        component_output = component.render(tag_name, locals:locals, attributes:attributes, &block)
        
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
      #
      # Returns (or concats if block given) rendered html and js.
      def vue_app(root_name = Vue::Helpers.root_name,
          locals:    {},
          **options,
          &block
        )
        
        #puts "\nvue_app '#{root_name}' with local-vars '#{local_variables.inject({}) { |c, i| c[i.to_s] = eval(i.to_s); c }}'"
        
        root_app = vue_root(root_name, locals:locals, **options)
        
        root_output = root_app.render(locals:locals, &block)
                
        if block_given?
          concat_content(root_output)
        else
          root_output
        end
      end

      
    end # Methods
  end # Helpers
end # Vue