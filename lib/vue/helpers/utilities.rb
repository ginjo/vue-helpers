module Vue
  module Helpers
  
    module Refinements
      refine String do
        def interpolate(**locals)
          gsub(/\#\{/, '%{') % locals
        end
        
        def camelize
          split(/[_-]/).collect(&:capitalize).join
        end
      end
    end
    
    module ModErb
      def initialize(*args)
        #puts "ERB.new(*args): #{args.to_yaml}"
        args[3] ||= Vue::Helpers.default_buffer_name
        super
      end
    end
    ::ERB.send(:prepend, ModErb)
    
    module ControllerPrepend
      def initialize(*args)
        super
        unless defined?(@outvar)
          @outvar ||= Vue::Helpers.default_buffer_name
        end
      end
    end
    
  end # Helpers
end # Vue
