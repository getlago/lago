# frozen_string_literal: true

module Jobs
  class MockStripeWebhookEventJob < ActiveJob::Base
    def perform(organization, request_body, response_body)
      @organization = organization
      @request_body = request_body.deep_symbolize_keys
      @response_body = response_body.deep_symbolize_keys

      @status = @response_body[:error] ? "failed" : "succeeded"

      # NOTE: Update Payment in our database because `PaymentRequests::Payments::StripeService.update_payment_status`
      #       relies on Payment.find_by(provider_payment_id: stripe_payment.id)
      lago_payment_id = @request_body[:metadata][:lago_payment_id]
      Payment.find(lago_payment_id).update!(provider_payment_id: payment_intent_id)

      result = PaymentProviders::Stripe::HandleEventService.call(
        organization:,
        event_json: build_event.to_json
      )
      result.raise_if_error!
    end

    def build_event
      {
        id: "evt_#{SecureRandom.hex(10)}",
        object: "event",
        created: Time.current.to_i,
        type: (status == "succeeded") ? "payment_intent.succeeded" : "payment_intent.payment_failed",
        data: {
          object: {
            id: payment_intent_id,
            object: "payment_intent",
            status: status.to_s,
            metadata: request_body[:metadata]
          }
        }
      }
    end

    private

    attr_reader :organization, :request_body, :status, :response_body

    def payment_intent_id
      response_body.dig(:error, :payment_intent, :id)
    end
  end
end
