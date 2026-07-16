# frozen_string_literal: true

module Middlewares
  class LogTracerMiddleware < BaseMiddleware
    def call(&block)
      LagoTracer.in_span("#{service_instance.class.name}#call") do
        call_next(&block)
      end
    end
  end
end
