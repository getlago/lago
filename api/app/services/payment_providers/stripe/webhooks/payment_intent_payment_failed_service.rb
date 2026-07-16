# frozen_string_literal: true

module PaymentProviders
  module Stripe
    module Webhooks
      class PaymentIntentPaymentFailedService < BaseService
        def call
          update_payment_status! "failed"
        end
      end
    end
  end
end
