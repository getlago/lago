# frozen_string_literal: true

module LagoUtils
  module RubySandbox
    class SandboxError < StandardError
      def initialize(initial_error:, backtrace: nil)
        @initial_error = initial_error
        @backtrace = backtrace
        super
      end

      attr_reader :initial_error, :backtrace
    end
  end
end
