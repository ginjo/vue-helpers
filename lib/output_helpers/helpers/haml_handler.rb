module Vue
  module OutputHelpers
    # Haml and Hamlit require different detection code
    #if defined?(Haml) && Tilt.template_for('.haml').to_s == "Padrino::Rendering::HamlTemplate"
    
    # Modified by Ginjo.
    #puts "OUTPUTHELPERS Tilt.template_for '.haml': #{Tilt.template_for('.haml')}"
    if defined?(Haml) && Tilt.template_for('.haml').to_s == "Tilt::HamlTemplate"
      #puts "OUTPUTHELPERS selected HamlHandler"
      ##
      # Handler for Haml templates.
      #
      class HamlHandler < AbstractHandler
        ##
        # Returns true if the block is for Haml
        #
        def engine_matches?(block)
          template.block_is_haml?(block)
        end

        ##
        # Captures the html from a block of template code for this handler.
        #
        def capture_from_template(*args, &block)
          engine_matches?(block) ? template.capture_haml(*args, &block) : yield(*args)
        end
        
        # Added by Ginjo to concat haml content to buffer.
        def concat_to_template(text="", context=nil)
          #puts "HAML CONCAT_TO_TEMPLATE: #{text}"
          template.haml_concat(text)
        end
      end
      OutputHelpers.register(:haml, HamlHandler)
    else
      #puts "OUTPUTHELPERS selected HamlitHandler"
      ##
      # Handler for Haml templates.
      #
      class HamlitHandler < AbstractHandler
        ##
        # Returns true if the block is for Hamlit.
        #
        def engine_matches?(block)
          block.binding.eval('defined? __in_hamlit_template')
        end
      end
      OutputHelpers.register(:haml, HamlitHandler)
    end
  end
end
