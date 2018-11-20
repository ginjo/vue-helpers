require "vue/helper/version"
require 'securerandom'
require 'erb'
require 'tilt'

module StringRefinements
  refine String do
    def interpolate(**locals)
      gsub(/\#\{/, '%{') % locals
    end
    
    def camelize
      split(/[_-]/).collect(&:capitalize).join
    end
  end
end

module Vue
  using StringRefinements
  
  class << self
    # Class defaults.
    # TODO: Copy these, as hash, to helper instance,
    # then allow helper to change them if necessary (through vue_component or yield_vue or source_vue methods).
    # Not yet, that's a deeper level of customization. Maybe next version. Remember that the helper instance only lasts for one request cycle.
    attr_accessor *%w(
      cache_store
      template_proc
      component_wrapper
      yield_wrapper
      script_wrapper
      root_wrapper
      root_el
      root_name
      callback_prefix
      template_engine
      views_path
    )
  end
  
  self.cache_store = {}
  #self.template_proc = Proc.new {|string| erb(string, layout:false)}
  self.template_engine = 'ERB'
  self.views_path = 'app/views'
  self.callback_prefix = '/vuecallback'
  self.root_name = "vue-app"
  
  self.template_proc = Proc.new do |str_or_sym, locals:{}|
    puts "CAlling template_proc with str_or_sym: #{str_or_sym}, and locals: #{locals}"
    tilt_template = case str_or_sym
      when Symbol; Tilt.new(File.join(Dir.getwd, Vue.views_path, "#{str_or_sym.to_s}.vue.#{Vue.template_engine.downcase}"))
      when String; Tilt.const_get("#{Vue.template_engine}Template").new(){str_or_sym}
    end
    tilt_template.render(binding, **locals)
  end
  

  
  
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

    # Inserts Vue component-call block in html template.
    # Name & file_name refer to file-name.vue.<template_engine> SFC file. Example: products.vue.erb.
    def vue_component(name, root_name = Vue.root_name, attributes:{}, tag:nil, file_name:nil, locals:{})
      
      # Parses SFC file, evaluating template code if exists.
      parsed_sfc = parse_vue_sfc((file_name || name).to_sym, locals:locals)
      
      # Compiles Vue.componenent definition from parsed SFC into a RootApp,
      # and store the resulting JS code in @vue_root hash.
      vue_root(root_name).components[name] = compile_vue_js(*parsed_sfc)

      # Adds 'is' attribute to html vue-component element,
      # if the user specifies an alternate 'tag' (default tag is name-of-component).
      el_name = tag || name
      if tag
        attributes['is'] = name
      end
            
      # Compiles attributes string from given ruby hash.
      attributes_string = attributes.inject(''){|o, kv| o.to_s << "#{kv[0]}=\"#{kv[1]}\" "}
      
      # Captures block of text passed to vue_component method.
      text = capture(buffer, &Proc.new)

      # Gets vue-component html tags.
      raw_output_template = Vue.component_wrapper || "
        <#{el_name} #{attributes_string}>
          #{text}
        </#{el_name}>
      "
      
      # Inserts data into vue-component html block. 
      interpolated_output_template = raw_output_template.interpolate(name:name, tag:tag, el_name:el_name, text:text, attributes_string:attributes_string)
      
      # Evaluates entire vue-component html block as template, and adds to output buffer.
      buffer << eval_ruby_template(interpolated_output_template, locals:locals)
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
    
    
    ### private
    
    # Stores all root apps defined by vue-helper, plus their compiled components.
    def vue_root(root_name = Vue.root_name)
      @vue_root ||= {}
      @vue_root[root_name.to_s] ||= RootApp.new
    end

    # Buffer tricks allow addition of 'capture' method for erb. From https://gist.github.com/seanami/496702
    def buffer
      @_out_buf
    end
    def capture(buffer)
      pos = buffer.size
      yield
      buffer.slice!(pos..buffer.size)
    end

    def parse_vue_sfc(template_file, locals:{})  # TODO: file_or_string. (I think it already does).
      raw = eval_ruby_template(template_file, locals:locals)
      name = template_file.to_s.split(/[. ]/)[0]
      a,template,c,script = raw.to_s.match(/(<template>(.*)<\/template>)*.*(<script>(.*)<\/script>)/m).to_a[1..-1]
      puts "PARSE_vue_sfc result: #{[template,script]}"
      [name, template, script]
    end
    
    def eval_ruby_template(template_text_or_file, locals:{})
      instance_exec(template_text_or_file, locals:locals, &Vue.template_proc)
    end

    def compile_vue_js(name, template, script)
      script.gsub!(/export\s+default\s*\{/, "Vue.component('#{name}', {template: `#{template}`,") << ")"
    end

    def build_vue(root_name = Vue.root_name, file_name:root_name, app_name:root_name.camelize) 
      root ||= ""
      components = vue_root(root_name).components
      if components.is_a?(Hash) && components.size > 0 && values=components.values
        root << values.join(";\n")
        root << ";\n"
      
        wrapper = Vue.root_wrapper ||
          parse_vue_sfc(file_name.to_sym, locals: {
            root_name:     root_name,
            app_name:      app_name,
            file_name:     file_name,
            vue_data_json: vue_root(root_name).data.to_json
          })[2] #||
          # <<-'EEOOFF'
          #   var #{app_name} = new Vue({
          #     el: (Vue.root_el || '##{root_name}'),
          #     data: #{vue_data_json}
          #   })
          # EEOOFF
              
        #root << wrapper.interpolate(vue_data_json: vue_root(root_name).data.to_json, root_name: root_name)
        root << wrapper
      end
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
