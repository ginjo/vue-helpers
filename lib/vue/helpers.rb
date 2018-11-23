require "vue/helpers/version"
require 'securerandom'
require 'erb'
require 'tilt'

#require 'vue/output_helpers'

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
  # TODO: I think template_engine is dynamic, or at least passed in arguments.
  self.template_engine = :erb
  self.views_path = 'app/views'
  self.callback_prefix = '/vuecallback'
  self.root_name = 'vue-app'
  self.yield_wrapper = '<script>#{compiled}</script>'
  self.script_wrapper = '<script src="#{callback_prefix}/#{key}"></script>'
  
  self.component_wrapper = '
    <#{el_name} #{attributes_string}>
      #{block_content}
    </#{el_name}>
  '
  
  self.root_wrapper = '
    var #{app_name} = new Vue({
      el: (Vue.root_el || "##{root_name}"),
      data: #{vue_data_json}
    })
  '
  
  
  
  # Instance represents a single vue root and all of its components.
  class RootApp
    attr_accessor :components, :data

    def initialize(*args, **opts)
      @components = opts[:components] || {}
      @data       = opts[:data] || {}
    end
  end
  
  
  # Include this module in your controller (or action, or route, or whatever).
  module Helpers
  
    #     def self.included(other)
    #       other.send :include, Vue::OutputHelpers
    #     end

    # Inserts Vue component-call block in html template.
    # Name & file_name refer to file-name.vue.<template_engine> SFC file. Example: products.vue.erb.
    def vue_component(name, root_name:Vue.root_name, attributes:{}, tag:nil, file_name:name, locals:{}, template_engine:current_template_engine, &block)
      puts "VUE_COMPONENT called with name: #{name}, root_name: #{root_name}, tag: #{tag}, file_name: #{file_name}, template_engine: #{template_engine}, block_given? #{block_given?}"

      component_content_ary = rendered_template(file_name:file_name, locals:locals, template_engine:template_engine)
      puts "VC #{name} component_content_ary: #{component_content_ary}"
      
      block_content = rendered_block(locals:locals, template_engine:template_engine, &block) if block_given?
      puts "VC #{name} block_content: #{block_content}"
      
      compiled_component_js = compile_component_js(name, *component_content_ary)
      puts "VC #{name} compiled_component_js: #{compiled_component_js}"
      
      vue_roots(root_name).components[name] = compiled_component_js
      
      component_output = compile_component_html_block(
        name: name,
        tag: tag,
        attributes: attributes,
        block_content: block_content,
        locals:locals
      )
       puts "VC component_output for '#{name}': #{component_output}"    
      
      if block_given?
        puts "Vue_component concating content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
        concat_content(component_output)
        return nil
      else
        puts "Vue_component returning content for '#{name}'"  #: #{component_output[0..32].gsub(/\n/, ' ')}"
        return component_output
      end
    end
  
    # Ouputs html script block of entire collection of vue roots and components.
    # Convert this to use ERB for wrapper.
    def vue_yield(root_name = Vue.root_name)
      #puts "VUE: #{vue}"
      return unless compiled = compile_vue_output(root_name)
      interpolated_wrapper = Vue.yield_wrapper.interpolate(compile_vue_output: compiled)
    end

    # Outputs html script block with src pointing to tmp file on server.
    # Convert this to use ERB for wrapper.
    def vue_src(root_name = Vue.root_name)
      return unless compiled = compile_vue_output(root_name)
      key = secure_key
      callback_prefix = Vue.callback_prefix
      Vue.cache_store[key] = compiled
      interpolated_wrapper = Vue.script_wrapper.interpolate(callback_prefix: callback_prefix, key: key)
    end     
    
    
    ### TODO: probably should be private.
    ### TODO: Should these be refinements, since they may interfere with other app or controller methods?
    
    # TODO: Patch this in with the Padrino code.
    def current_template_engine
      #current_engine || Vue.template_engine
      Tilt.default_mapping.template_map.invert[Tilt.current_template] || Vue.template_engine
    end
    
    def template_path(name, template_engine:current_template_engine)
      tp = File.join(Dir.getwd, Vue.views_path, "#{name.to_s}.vue.#{template_engine}")
      puts "Template_path generated for '#{name}': #{tp}"
      tp
    end
    
    # Stores all root apps defined by vue-helpers, plus their compiled components.
    def vue_roots(root_name = Vue.root_name)
      @vue_roots ||= {}
      @vue_roots[root_name.to_s] ||= RootApp.new
    end
    
    def rendered_block(locals:{}, template_engine:current_template_engine, &block)
      block_content = capture_html(&block) if block_given?
      rendered_block_content = render_ruby_template(block_content.to_s, template_engine:template_engine, locals:locals)
    end
    
    def rendered_template(file_name:nil, locals:{}, template_engine:current_template_engine)
      # template, script = parse_vue_sfc(file_name.to_sym)
      # r_template = render_ruby_template(template, locals:locals, template_engine:template_engine)
      # r_script   = render_ruby_template(script, locals:locals, template_engine:template_engine)
      # [r_template, r_script]
      
      rendered_vue_file = render_ruby_template(file_name.to_sym, locals:locals, template_engine:template_engine)
      puts "RENDERED_vue_file for '#{file_name}': #{rendered_vue_file}"
      parse_vue_sfc(rendered_vue_file.to_s)
    end
    
    def compile_component_html_block(name:nil, tag:nil, attributes:{}, block_content:'', locals:{})
      # Adds 'is' attribute to html vue-component element,
      # if the user specifies an alternate 'tag' (default tag is name-of-component).
      el_name = tag || name
      if tag
        attributes['is'] = name
      end
            
      # Compiles attributes string from given ruby hash.
      attributes_string = attributes.inject(''){|o, kv| o.to_s << "#{kv[0]}=\"#{kv[1]}\" "}      
      
      rendered_component_block_template = Vue.component_wrapper.interpolate(**
        {
          name:name,
          tag:tag,
          el_name:el_name,
          block_content:block_content,
          attributes_string:attributes_string
        }.merge(locals)
      ).to_s
    end

    def parse_vue_sfc(template_text_or_file)
      raw_template = begin
        case template_text_or_file
        when Symbol; File.read(template_path(template_text_or_file))
        when String; template_text_or_file
        end
      rescue
        puts "Parse_vue_sfc error getting template file: #{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}...: #{$!}"
        nil
      end
      a,template,c,script = raw_template.to_s.match(/(<template>(.*)<\/template>)*.*(<script>(.*)<\/script>)/m).to_a[1..-1]
      #{vue_template:template, vue_script:script}
      [template, script]
    end
    
    # TODO: Do we need this: 'ERB::Util.html_escape string'. It will convert all html tags like this: "Hi I&#39;m some text. 2 &lt; 3".
    def render_ruby_template(template_text_or_file, locals:{}, template_engine:current_template_engine)
      #puts "RENDER_ruby_template(\"#{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}\", locals:<locals>, template_engine:#{template_engine})"
        
      tilt_template = begin
        case template_text_or_file
        when Symbol; Tilt.new(template_path(template_text_or_file, template_engine:template_engine))
        when String; Tilt.template_for(template_engine).new(){template_text_or_file}
        end
      rescue
        puts "Render_ruby_template error building tilt template for #{template_text_or_file.to_s[0..32].gsub(/\n/, ' ')}...: #{$!}"
        nil
      end
      tilt_template.render(self, **locals) if tilt_template.is_a?(Tilt::Template)
    end

    #def compile_component_js(name, template, script)
    def compile_component_js(name, vue_template=nil, vue_script=nil)
      if vue_script
        # Yes, this looks weird, but remember we're just replacing the beginning of the script block.
        vue_script.gsub!(/export\s+default\s*\{/, "Vue.component('#{name}', {template: `#{vue_template}`,") << ")"
      end
    end

    def compile_vue_output(root_name = Vue.root_name, file_name:root_name, app_name:root_name.camelize, template_engine:current_template_engine, &block) 
      vue_output = ""
      
      components = vue_roots(root_name).components
      if components.is_a?(Hash) && components.size > 0 && values=components.values
        vue_output << values.join(";\n")
        vue_output << ";\n"
      end
      
      locals = {
        root_name:        root_name,
        app_name:         app_name,
        file_name:        file_name,
        template_engine:  template_engine,
        vue_data_json:    vue_roots(root_name).data.to_json
      }
      
      # {block_content:block_content, vue_sfc:{name:name, vue_template:template, vue_script:script}}
      rendered_template_script = \
        rendered_template(file_name:file_name.to_sym, locals:locals, template_engine:template_engine).to_a[1] ||
        Vue.root_wrapper.interpolate(**locals)
      
      vue_output << rendered_template_script
    end  # compile_vue_output
        
    def secure_key
      SecureRandom.urlsafe_base64(32)
    end
    
    
    # Capture & Concat
    # See https://gist.github.com/seanami/496702
    
    def buffer(name=:_out_buf)
      #@_out_buf
      instance_variable_get("@#{name}")
    end
    def capture_html(*args, &block)
      pos = buffer.size
      yield(*args)
      buffer.slice!(pos..buffer.size)
    end
    def concat_content(text='')
      buffer << text
    end

  end # Helpers

  
  # Rack middleware to serve sourced vue block, see https://redpanthers.co/rack-middleware/.
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
