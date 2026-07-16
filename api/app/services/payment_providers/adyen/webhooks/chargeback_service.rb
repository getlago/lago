# frozen_string_literal: true

module PaymentProviders
  module Adyen
    module Webhooks
      class ChargebackService < BaseService
        def call
          status = event["additionalData"]["disputeStatus"]
          reason = event["reason"]
          provider_payment_id = event["pspReference"]

          payment = Payment.find_by(provider_payment_id:)
          return result.not_found_failure!(resource: "adyen_payment") unless payment

          if status == "Lost" && event["success"] == "true"
            return ::Payments::LoseDisputeService.call(payment:, payment_dispute_lost_at:, reason:)
          end

          result
        end

        private

        def payment_dispute_lost_at
          Time.zone.parse(event["eventDate"])
        end
      end
    end
  end
end
