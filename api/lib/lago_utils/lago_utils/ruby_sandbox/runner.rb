# frozen_string_literal: true

require "open3"

module LagoUtils
  module RubySandbox
    class Runner
      def initialize(code)
        @code = code
      end

      def run
        result = nil
        error = nil

        temp_file = prepare_ruby_file

        Open3.popen3("ruby #{temp_file.path}", chdir: "/tmp") do |_, stdout, stderr, _|
          error = stderr.read
          result = stdout.read
        end

        raise SandboxError.new(initial_error: error) if error.present?

        parsed_result = JSON.parse(result)

        if parsed_result.is_a?(Hash) && parsed_result["type"] == "error"
          raise SandboxError.new(
            initial_error: parsed_result["error"],
            backtrace: parsed_result["backtrace"]
          )
        end

        parsed_result
      ensure
        temp_file.unlink
      end

      private

      attr_reader :code

      def sanitized_code
        @sanitized_code ||= LagoUtils::RubySandbox::Sanitizer.new(code).sanitize
      end

      def prepare_ruby_file
        file = Tempfile.new("lago-ruby-sandbox")
        file.write(<<~STRING)
          require 'json'
          require 'bigdecimal'

          #{LagoUtils::RubySandbox::SafeEnvironment::SAFE_ENV}

          result = begin
            #{sanitized_code}
          rescue Exception => e
            { type: 'error', error: e.message, backtrace: e.backtrace }
          end

          print JSON.dump(result)
        STRING
        file.rewind
        file
      end
    end
  end
end
