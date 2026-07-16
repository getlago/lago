# frozen_string_literal: true

module Middlewares
  class DatadogMiddleware < BaseMiddleware
    def before_call
      @span = Datadog::Tracing.trace("service.call", service: service_name, resource: service_instance.class.name)
    end

    def after_call(result)
      return if @span.nil?

      if result.success?
        @span.set_tag("result.status", "success")
      else
        @span.set_tag("result.status", "failure")
        @span.record_exception(result.error)
      end

      @span.finish
    end

    def handle_error(error)
      return if @span.nil?

      @span.set_tag("result.status", "failure")
      @span.record_exception(error)
      @span.finish
    end

    private

    def service_name
      @service_name ||= ENV["DD_SERVICE_NAME"] || "lago-api"
    end
  end
end
