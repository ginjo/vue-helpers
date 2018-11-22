if defined?(ActiveSupport::SafeBuffer)
  SafeBuffer = ActiveSupport::SafeBuffer
else
  # Modified by Ginjo
  #require 'padrino/safe_buffer'
  require_relative 'safe_buffer'

  SafeBuffer = Vue::SafeBuffer

  class String
    def html_safe
      SafeBuffer.new(self)
    end
  end

  class Object
    def html_safe?
      false
    end
  end

  class Numeric
    def html_safe?
      true
    end
  end
end
