# frozen_string_literal: true

module Webhooks
  module Events
    class ErrorService < Webhooks::BaseService
      EventError = Data.define(:error, :event)

      private

      def current_organization
        @current_organization ||= Organization.find(object.organization_id)
      end

      def object_serializer
        ::V1::EventErrorSerializer.new(
          EventError.new(
            error: options[:error],
            event: object
          ),
          root_name: "event_error"
        )
      end

      def webhook_type
        "event.error"
      end

      def object_type
        "event_error"
      end
    end
  end
end
