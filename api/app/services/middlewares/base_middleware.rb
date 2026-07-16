# frozen_string_literal: true

module Middlewares
  class BaseMiddleware
    def initialize(service_instance, next_middleware, *args, **kwargs)
      @service_instance = service_instance
      @next_middleware = next_middleware
      @args = args
      @kwargs = kwargs
    end

    def call(&block)
      before_call

      result = call_next(&block)

      after_call(result)

      result
    rescue => e
      handle_error(e)

      raise
    end

    attr_reader :service_instance, :next_middleware, :args, :kwargs

    private

    def call_next(&block)
      @next_middleware.call(&block)
    end

    def before_call
      # Override this method in subclasses
    end

    def after_call(result)
      # Override this method in subclasses
    end

    def handle_error(error)
      # Override this method in subclasses
    end
  end
end
