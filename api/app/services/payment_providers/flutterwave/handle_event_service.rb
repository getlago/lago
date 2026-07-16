# frozen_string_literal: true

module PaymentProviders
  module Flutterwave
    class HandleEventService < BaseService
      EVENT_MAPPING = {
        "charge.completed" => PaymentProviders::Flutterwave::Webhooks::ChargeCompletedService
      }.freeze

      def initialize(organization:, event_json:)
        @organization = organization
        @event_json = event_json

        super
      end

      def call
        event_type = event["event"]
        service_class = EVENT_MAPPING[event_type]

        return result unless service_class

        begin
          service_class.call!(organization_id: organization.id, event_json:)
        rescue => e
          Rails.logger.error("Flutterwave event processing error: #{e.message}")
        end

        result
      end

      private

      attr_reader :organization, :event_json

      def event
        @event ||= JSON.parse(event_json)
      end
    end
  end
end
