require "vue/helper/version"
require 'securerandom'
require 'erb'
require 'tilt'

require 'output_helpers/output_helpers'

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
  
  self.template_proc = Proc.new do |str_or_sym, locals:{}, template_engine:Vue.template_engine|
    #puts "CAlling template_proc with str_or_sym: #{str_or_sym}, and locals: #{locals}"
    tilt_template = \
      begin
        case str_or_sym
        when Symbol; Tilt.new(File.join(Dir.getwd, Vue.views_path, "#{str_or_sym.to_s}.vue.#{Vue.template_engine.downcase}"))
        when String; Tilt.const_get("#{template_engine}Template").new(){str_or_sym}
        end
      rescue
        puts "Template proc: error retrieving template for #{str_or_sym}: #{$!}"
        nil
      end
    tilt_template.render(binding, **locals) if tilt_template.is_a?(Tilt::Template)
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
  
    def self.included(other)
      other.send :include, Vue::OutputHelpers
    end

    # Inserts Vue component-call block in html template.
    # Name & file_name refer to file-name.vue.<template_engine> SFC file. Example: products.vue.erb.
    # TODO: Implement template_engine here.
    # TODO: Implement custom wrapper from template file (like I did with the vue root).
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
      prc = Proc.new if block_given?
      block_content = capture_html(&prc)
      
      puts "CAPTURED block_content: #{block_content}"
      concat_content("CONCAT TEST")
      puts "PROPER HANDLER: #{find_proper_handler}"
      puts "CURRENT ENGINE: #{current_engine}"
      
      # Gets vue-component html wrapper.
      component_block_template = Vue.component_wrapper || "
        <<%= el_name %> <%= attributes_string %>>
          <%= block_content %>
        </<%= el_name %>>
      "
      # Evaluates entire vue-component html block as template, and adds to output buffer.
      # TODO: The template_engine should be variable, but based on what?
      rendered_template = render_ruby_template(component_block_template,
        template_engine:'ERB',
        locals:{
          name:name,
          tag:tag,
          el_name:el_name,
          block_content:block_content,
          attributes_string:attributes_string
        }.merge(locals:locals)
      ).to_s
      
      #buffer << rendered_template
      concat_content(rendered_template)
    end
  
    # Ouputs html script block of entire collection of vue roots and components.
    # Convert this to use ERB for wrapper.
    def vue_yield(root_name = Vue.root_name)
      #puts "VUE: #{vue}"
      return unless compiled = build_vue(root_name)
      wrapper = Vue.yield_wrapper || '<script>#{compiled}</script>'
      interpolated_wrapper = wrapper.interpolate(build_vue: compiled)
    end

    # Outputs html script block with src pointing to tmp file on server.
    # Convert this to use ERB for wrapper.
    def vue_src(root_name = Vue.root_name)
      return unless compiled = build_vue(root_name)
      key = secure_key
      callback_prefix = Vue.callback_prefix
      Vue.cache_store[key] = compiled
      wrapper = Vue.script_wrapper || '<script src="#{callback_prefix}/#{key}"></script>'
      interpolated_wrapper = wrapper.interpolate(callback_prefix: callback_prefix, key: key)
    end     
    
    
    ### TODO: probably should be private.
    ### TODO: Should these be refinements, since they may interfere with other app or controller methods?
    
    # Stores all root apps defined by vue-helper, plus their compiled components.
    def vue_root(root_name = Vue.root_name)
      @vue_root ||= {}
      @vue_root[root_name.to_s] ||= RootApp.new
    end

    #   # Buffer tricks allow addition of 'capture' method for erb. From https://gist.github.com/seanami/496702
    #   def buffer
    #     @_out_buf ||= ''
    #   end
    #   def capture(buffer)
    #     pos = buffer.size
    #     yield
    #     buffer.slice!(pos..buffer.size)
    #   end

    
    #   # These capture/concat methods were found here:
    #   # https://www.rubydoc.info/gems/darkhelmet-sinatra_more/Sinatra/MarkupPlugin/OutputHelpers#capture_html-instance_method
    #   # It looks like each templating engine already has some mechanism to handle these,
    #   # and these methods just give them a standard interface.
    #   # TODO: Add slim (and others?) to these methods.
    #   #
    #   def capture_html(*args, &block)
    #     if self.respond_to?(:is_haml?) && is_haml?
    #       block_is_haml?(block) ? capture_haml(*args, &block) : block.call
    #     elsif has_erb_buffer?
    #       result_text = capture_erb(*args, &block)
    #       result_text.present? ? result_text : (block_given? && block.call(*args))
    #     else # theres no template to capture, invoke the block directly
    #       puts "CAPTURE_HTML - generic calling block"
    #       block.call(*args)
    #     end
    #   end
    #   #
    #   #
    #   def concat_content(text="")
    #     if self.respond_to?(:is_haml?) && is_haml?
    #       haml_concat(text)
    #     elsif has_erb_buffer?
    #       erb_concat(text)
    #     else # theres no template to concat, return the text directly
    #       puts "CONCAT_CONTENT - generic returning text"
    #       text
    #     end
    #   end
    #   #
    #   # Returns true if an erb buffer is detected
    #   # has_erb_buffer? => true
    #   def has_erb_buffer?
    #     !@_out_buf.nil?
    #   end

    def parse_vue_sfc(template_file, locals:{}, template_engine:Vue.template_engine)  # TODO: file_or_string. (I think it already does).
      raw = render_ruby_template(template_file, locals:locals, template_engine:template_engine)
      name = template_file.to_s.split(/[. ]/)[0]
      a,template,c,script = raw.to_s.match(/(<template>(.*)<\/template>)*.*(<script>(.*)<\/script>)/m).to_a[1..-1]
      #puts "PARSE_vue_sfc result: #{[template,script].to_yaml}"
      [name, template, script]
    end
    
    # TODO: This needs to handle default templates (which are in erb)
    # regardless of whether user declares alternate template engine.
    # TODO: You might want to use this: 'ERB::Util.html_escape string'
    def render_ruby_template(template_text_or_file, locals:{}, template_engine:Vue.template_engine)
      puts "RENDER_ruby_template(#{template_text_or_file}, locals:#{locals}, template_engine:#{template_engine})"
      instance_exec(template_text_or_file, locals:locals, template_engine:template_engine, &Vue.template_proc)
    end

    def compile_vue_js(name, template, script)
      if script
        # Yes, this looks weird, but remember we're just replacing the beginning of the script block.
        script.gsub!(/export\s+default\s*\{/, "Vue.component('#{name}', {template: `#{template}`,") << ")"
      end
    end

    def build_vue(root_name = Vue.root_name, file_name:root_name, app_name:root_name.camelize, template_engine:Vue.template_engine) 
      root ||= ""
      components = vue_root(root_name).components
      if components.is_a?(Hash) && components.size > 0 && values=components.values
        root << values.join(";\n")
        root << ";\n"
        
        locals = {
          root_name:     root_name,
          app_name:      app_name,
          file_name:     file_name,
          vue_data_json: vue_root(root_name).data.to_json
        }
      
        wrapper = (
          # User defined wrapper in class variable.
          Vue.root_wrapper ||
        
          # User defined wrapper in <root_name>.vue.<Vue.template_engine>.
          parse_vue_sfc(file_name.to_sym, template_engine:template_engine, locals: locals)[2] ||
          
          # Default wrapper.
          render_ruby_template("
            var <%= app_name %> = new Vue({
              el: (Vue.root_el || '#<%= root_name %>'),
              data: <%= vue_data_json %>
            })
          ",
            template_engine: 'ERB',
            locals: locals
          )
        ) # end-of-wrapper
        
        root << wrapper
      end
    end 
        
    def secure_key
      SecureRandom.urlsafe_base64(32)
    end

  end # Helper

  
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
