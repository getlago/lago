# frozen_string_literal: true

module Webhooks
  module Events
    class ValidationErrorsService < Webhooks::BaseService
      private

      def current_organization
        object
      end

      def object_serializer
        ::V1::EventsValidationErrorsSerializer.new(
          options[:errors] || {},
          root_name: "events_errors"
        )
      end

      def webhook_type
        "events.errors"
      end

      def object_type
        "events_errors"
      end
    end
  end
end
