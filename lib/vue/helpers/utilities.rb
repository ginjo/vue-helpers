module Vue
  module Helpers
  
    module CoreRefinements
      refine String do
        def interpolate(**locals)
          gsub(/\#\{/, '%{') % locals
        end
        
        def camelize
          #split(/[_-]/).collect(&:capitalize).join
          split(/\W|_/).collect(&:capitalize).join
        end
        
        def kebabize
          split(/\W|_/).collect(&:downcase).join('-')
        end
        
        def escape_backticks
          gsub(/\`/,'\\\`')
        end
      end
      
      refine Hash do
        def to_html_attributes
          inject(''){|o, kv| o.to_s << "#{kv[0]}=\"#{kv[1]}\" "}
        end
      end
      
      refine Dir.singleton_class do
        # Returns list of files breadth-first.
        # Pass :no_recurse=>true to block directory recursion.
        # Pass a block to yield each found path to the block.
        def breadth_first(pattern, flags=0, base: Dir.getwd, **opts, &block)
          files, dirs = [], []
          Dir.glob(File.join(base, pattern), flags).each{|path| FileTest.directory?(path) ? dirs.push(path) : files.push(path)}
          
          files.each{|f| yield(f)} if block_given?
          dirs.each{|dir| files.concat(breadth_first(pattern, flags, base:dir, &block))} unless opts[:no_recurse]
      
          files
        end
      end
    end # CoreRefinements
    
    module ModErb
      def initialize(*args)
        #puts "ERB.new(*args): #{args.to_yaml}"
        args[3] ||= Vue::Helpers.default_outvar
        super
      end
    end
    ::ERB.send(:prepend, ModErb)
    
    module ControllerPrepend
      def initialize(*args)
        super
        unless defined?(@outvar)
          @outvar ||= Vue::Helpers.default_outvar
        end
      end
    end
    
  end # Helpers
end # Vue
