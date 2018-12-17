require_relative 'utilities'
require_relative 'helper_refinements'
require_relative 'vue_component'
require_relative 'vue_root'

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
    
  end # Helpers
end # Vue

