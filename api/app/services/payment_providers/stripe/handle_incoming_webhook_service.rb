# frozen_string_literal: true

module PaymentProviders
  module Stripe
    class HandleIncomingWebhookService < BaseService
      extend Forwardable

      def initialize(inbound_webhook:)
        @inbound_webhook = inbound_webhook

        super
      end

      def call
        PaymentProviders::Stripe::HandleEventJob.perform_later(
          organization:,
          event: stripe_event.to_json
        )

        result.event = stripe_event
        result
      rescue JSON::ParserError
        result.service_failure!(code: "webhook_error", message: "Invalid payload")
      end

      private

      def_delegators :@inbound_webhook, :organization, :payload

      def stripe_event
        @stripe_event ||= ::Stripe::Event.construct_from(json_payload)
      end

      def json_payload
        JSON.parse(payload, symbolize_names: true)
      end
    end
  end
end
