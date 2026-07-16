# frozen_string_literal: true

module LagoUtils
  module RubySandbox
    class Sanitizer
      def initialize(code)
        @code = code || ""
      end

      def sanitize
        code.gsub(/require\s/, 'raise NoMethodError, "require is not allowed";')
      end

      private

      attr_reader :code
    end
  end
end
