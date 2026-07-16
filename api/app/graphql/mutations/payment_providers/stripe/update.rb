# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Stripe
      class Update < Base
        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateStripePaymentProvider"
        description "Update Stripe payment provider"

        input_object_class Types::PaymentProviders::UpdateInput

        type Types::PaymentProviders::Stripe
      end
    end
  end
end
