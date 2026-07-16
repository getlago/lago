# frozen_string_literal: true

module PaymentProviders
  module Cashfree
    class HandleEventService < BaseService
      EVENT_MAPPING = {
        "PAYMENT_LINK_EVENT" => PaymentProviders::Cashfree::Webhooks::PaymentLinkEventService
      }.freeze

      def initialize(organization:, event_json:)
        @organization = organization
        @event_json = event_json

        super
      end

      def call
        EVENT_MAPPING[event["type"]].call!(organization_id: organization.id, event_json:)

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
