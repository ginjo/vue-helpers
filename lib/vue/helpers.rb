require "vue/helpers/version"

# See below...
# require_relative 'helpers/methods'
# require_relative 'helpers/server'

module Vue
  module Helpers
  
    @defaults = {
      cache_store:             {},
      callback_prefix:         '/vuecallback',
      default_outvar:          '@_erbout',
      external_resource:       false,
      minify:                  false,
      register_local:          false,
      root_name:               'vue-app',
      template_engine:         :erb, # This should not force template_engine, only recommend if no other can be found.
      template_literal:        true,
      views_path:              ['app/views'],
      vue_outvar:              '@_vue_outvar',

                               # These are ugly now, becuase I wanted to use double-quotes as the outter-quotes.
      component_call_html:     "<\#{el_name} \#{attributes_string}>\#{block_content}</\#{el_name}>",
      external_resource_html:  "\n<script src=\"\#{callback_prefix}/\#{key}\"></script>",
      inline_script_html:      "\n<script>\#{compiled}\n</script>\n",
      root_app_html:           '<div id="#{root_name}">#{block_content}</div>#{root_script_output}',
      root_object_js:          'var #{app_name} = new Vue({el: ("##{root_name}"), components: {#{components}}, data: #{vue_data_json}})',
      x_template_html:         "\n<script type=\"text/x-template\" id=\"\#{name}-template\">\#{template}</script>",
    }
    
    @defaults.keys.each{|k| define_singleton_method(k){@defaults[k]}}
    
    class << self
      attr_accessor :defaults      
    end

    def self.included(other)
      other.send(:include, Vue::Helpers::Methods)
    end
    
  end 
end

require_relative 'helpers/methods'
require_relative 'helpers/server'
