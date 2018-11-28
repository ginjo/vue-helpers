module Vue
  module Helpers
  
    # Instance represents a single vue root and all of its components.
    class RootApp
      attr_accessor :components, :data
  
      def initialize(*args, **opts)
        @components = opts[:components] || {}
        @data       = opts[:data] || {}
      end
    end
    
  end # Helpers
end # Vue