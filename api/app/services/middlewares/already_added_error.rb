# frozen_string_literal: true

module Middlewares
  class AlreadyAddedError < StandardError
    def initialize(middleware_class, service_class)
      super("Middleware #{middleware_class} is already present on #{service_class}")
    end
  end
end
