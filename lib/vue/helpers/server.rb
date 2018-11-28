require 'rack'
require_relative 'methods'
require_relative 'utilities'

module Vue
  module Helpers
    using Refinements
    
    # Rack middleware to serve sourced vue block, see https://redpanthers.co/rack-middleware/.
    # Usage: use Vue::Helpers::Server
    
    class Server
      def initialize(app)
        @app = app
      end
      
      def call(env)
        req = Rack::Request.new(env)
        case req.path_info
        #when /^\/vuesource\/([A-Za-z0-9\-_]{43})$/
        when /^#{Vue::Helpers.callback_prefix}\/([A-Za-z0-9\-_]{43})$/
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
        Vue::Helpers.cache_store.delete(key)
        #Vue::Helpers.cache_store[key]
      end
      
    end # Source
  end # Helpers
end