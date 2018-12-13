require "vue/helpers/version"

require_relative 'helpers/methods'
require_relative 'helpers/server'

module Vue
  module Helpers
  
    def self.included(other)
      other.send(:include, Vue::Helpers::Methods)
      
      #Rails.application.configure.middleware.use Vue::Helpers::Server
      # NOTE: Rack middleware cannot be dynamically inserted at runtime.
      # So while this works in Sinatra (at load time), it will not work in rails,
      # at least not as writting here.
      #
      # if other.respond_to?(:use)
      #   other.send(:use, Vue::Helpers::Server)
      # elsif other.ancestors.find{|a| a.to_s[/ApplicationHelper/]}
      #   Rails.application.configure.middleware.use Vue::Helpers::Server
      # end
    end
    
  end 
end
