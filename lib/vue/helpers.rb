require "vue/helpers/version"

require_relative 'helpers/methods'
require_relative 'helpers/server'

module Vue
  module Helpers
  
    def self.included(other)
      other.send(:include, Vue::Helpers::Methods)
      # TODO: This only handles Sinatra (and maybe Rack).
      # Find a way to make this work in Rails (and others?).
      if other.respond_to?(:use)
        other.send(:use, Vue::Helpers::Server)
      end
    end
    
  end 
end
