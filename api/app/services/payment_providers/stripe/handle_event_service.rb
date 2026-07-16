# frozen_string_literal: true

module PaymentProviders
  module Stripe
    class HandleEventService < BaseService
      EVENT_MAPPING = {
        "setup_intent.succeeded" => PaymentProviders::Stripe::Webhooks::SetupIntentSucceededService,
        "payment_intent.succeeded" => PaymentProviders::Stripe::Webhooks::PaymentIntentSucceededService,
        "payment_intent.payment_failed" => PaymentProviders::Stripe::Webhooks::PaymentIntentPaymentFailedService,
        "customer.updated" => PaymentProviders::Stripe::Webhooks::CustomerUpdatedService,
        "charge.dispute.closed" => PaymentProviders::Stripe::Webhooks::ChargeDisputeClosedService,
        "payment_intent.canceled" => PaymentProviders::Stripe::Webhooks::PaymentIntentPaymentFailedService
      }.freeze

      def initialize(organization:, event_json:)
        @organization = organization
        @event_json = event_json

        super
      end

      def call
        unless PaymentProviders::StripeProvider::WEBHOOKS_EVENTS.include?(event.type)
          Rails.logger.warn("Unexpected stripe event type: #{event.type}")
          return result
        end

        if EVENT_MAPPING[event.type].present?
          EVENT_MAPPING[event.type].call(
            organization_id: organization.id,
            event:
          ).raise_if_error!

          return result
        end

        case event.type
        when "payment_method.detached"
          PaymentProviderCustomers::StripeService
            .new
            .delete_payment_method(
              organization_id: organization.id,
              stripe_customer_id: event.data.object.customer || event.data.previous_attributes.customer,
              payment_method_id: event.data.object.id,
              metadata: event.data.object.metadata.to_h.symbolize_keys
            ).raise_if_error!
        when "charge.refund.updated"
          CreditNotes::Refunds::StripeService
            .new.update_status(
              provider_refund_id: event.data.object.id,
              status: event.data.object.status,
              metadata: event.data.object.metadata.to_h.symbolize_keys
            )
        end
      rescue BaseService::NotFoundFailure => e
        # NOTE: Error with stripe sandbox should be ignord
        raise if event.livemode

        Rails.logger.warn("Stripe resource not found: #{e.message}. JSON: #{event_json}")
        BaseService::Result.new # NOTE: Prevents error from being re-raised
      end

      private

      attr_reader :organization, :body, :event_json

      def event
        @event ||= ::Stripe::Event.construct_from(JSON.parse(event_json))
      end
    end
  end
end
