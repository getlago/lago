# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Stripe
      class Create < Base
        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "AddStripePaymentProvider"
        description "Add Stripe API keys to the organization"

        input_object_class Types::PaymentProviders::StripeInput

        type Types::PaymentProviders::Stripe
      end
    end
  end
end
