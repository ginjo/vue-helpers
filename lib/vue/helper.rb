require "vue/helper/version"
require 'securerandom'

module StringRefinements
  refine String do
    def interpolate(**locals)
      gsub(/\#\{/, '%{') % locals
    end
  end
end

module Vue
  using StringRefinements
  
  class << self
    attr_accessor *%w(
      cache_store
      render_proc
      component_wrapper
      yield_wrapper
      script_wrapper
      root_wrapper
      root_el
      root_name
      callback_prefix
    )
  end
  
  self.cache_store = {}
  #self.render_proc = Proc.new {|string| erb(string, layout:false)}
  self.render_proc = Proc.new do |str_or_sym|
    puts "CAlling render_proc with str_or_sym: #{str_or_sym}"
    input_string = case str_or_sym
      when File; File.read(str_or_sym)
      when Symbol; File.read(File.join(Dir.getwd, 'app', 'views', "#{str_or_sym.to_s}.erb" ))
      when String; str_or_sym
    end
    puts "CAlling render_proc with input_string: #{input_string}"
    ERB.new(input_string).result(binding)
  end
  self.callback_prefix = '/vuecallback'
  self.root_name = "vue-app"
  
  
  # Instance represents a single vue root and all of its components.
  class RootApp
    attr_accessor :components, :data

    def initialize(*args, **opts)
      @components = opts[:components] || {}
      @data       = opts[:data] || {}
    end
  end
  
  
  # Include this module in your controller (or action, or route, or whatever).
  module Helper
    
    def vue_helper(root_name = Vue.root_name)
      @vue_helper ||= {}
      @vue_helper[root_name.to_s] ||= RootApp.new
    end

    # Buffer tricks allow addition of 'capture' method. From https://gist.github.com/seanami/496702
    def buffer
      @_out_buf
    end
    def capture(buffer)
      pos = buffer.size
      yield
      buffer.slice!(pos..buffer.size)
    end

    def parse_vue_sfc(erb_file)  # TODO: file_or_string
      raw = instance_exec(erb_file, &Vue.render_proc) #erb(erb_file, layout:false)
      name = erb_file.to_s.split(/[. ]/)[0]
      template, script = raw.to_s.match(/<template>(.*)<\/template>.*<script>(.*)<\/script>/m).to_a[1..-1]
      [name, template, script]
    end

    def compile_vue_js(name, template, script)
      script.gsub!(/export\s+default\s*\{/, "Vue.component('#{name}', {template: `#{template}`,") << ")"
    end

    def vue_component(name, root_name = Vue.root_name, attributes:{}, tag:nil)
      vue_helper(root_name).components[name] = compile_vue_js(*parse_vue_sfc(:"#{name}.vue"))

      if tag
        attributes['is'] = name
      end
      
      attributes_string = attributes.inject(''){|o, kv| o.to_s << "#{kv[0]}=\"#{kv[1]}\" "}
      text = capture(buffer, &Proc.new)
      el_name = tag || name

      #block_output = erb(<<-EEOOFF, layout:false)
      raw_output_template = Vue.component_wrapper || "
        <#{el_name} #{attributes_string}>
          #{text}
        </#{el_name}>
      "
      
      interpolated_output_template = raw_output_template.interpolate(name: name, tag: tag, el_name: el_name, text: text, attributes_string: attributes_string)
      #buffer << block_output
      buffer << instance_exec(interpolated_output_template, &Vue.render_proc)
    end

    def build_vue(root_name = Vue.root_name) 
      root ||= ""
      components = vue_helper(root_name).components
      if components.is_a?(Hash) && components.size > 0 && values=components.values
        root << values.join(";\n")
        root << ";\n"
      
        wrapper = Vue.root_wrapper || <<-'EEOOFF'
          var App = new Vue({
            el: (Vue.root_el || '##{root_name}'),
            data: #{vue_data_json}
          })
        EEOOFF
              
        root << wrapper.interpolate(vue_data_json: vue_helper(root_name).data.to_json, root_name: root_name)
      end
    end

    def yield_vue(root_name = Vue.root_name)
      #puts "VUE: #{vue}"
      return unless compiled = build_vue(root_name)
      wrapper = Vue.yield_wrapper || '<script>#{compiled}</script>'
      interpolated_wrapper = wrapper.interpolate(build_vue: compiled)
    end

    def source_vue(root_name = Vue.root_name)
      return unless compiled = build_vue(root_name)
      key = secure_key
      callback_prefix = Vue.callback_prefix
      Vue.cache_store[key] = compiled
      wrapper = Vue.script_wrapper || '<script src="#{callback_prefix}/#{key}"></script>'
      interpolated_wrapper = wrapper.interpolate(callback_prefix: callback_prefix, key: key)
    end      
        
    def secure_key
      SecureRandom.urlsafe_base64(32)
    end

  end # Helper

  
  # Middleware to handle sourced vue block, see https://redpanthers.co/rack-middleware/.
  class Source
    def initialize(app)
      @app = app
    end
    
    def call(env)
      req = Rack::Request.new(env)
      case req.path_info
      #when /^\/vuesource\/([A-Za-z0-9\-_]{43})$/
      when /^#{Vue.callback_prefix}\/([A-Za-z0-9\-_]{43})$/
        #puts "vue_source match: #{$1}"
        if content = get_content($1)
          [200, {"Content-Type" => "text/javascript"}, [content]]
        else
          [404, {"Content-Type" => "text/html"}, ['']]
        end
      when /^\/pingm$/
        [200, {"Content-Type" => "text/javascript"}, ['Ok']]
      else
        #[404, {"Content-Type" => "text/html"}, ["I'm Lost!"]]
        @app.call(env)
      end
    end
    
    def get_content(key)
      Vue.cache_store.delete(key)
      #Vue.cache_store[key]
    end
  end # Source

end
