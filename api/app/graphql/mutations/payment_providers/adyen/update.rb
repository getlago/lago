# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Adyen
      class Update < Base
        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateAdyenPaymentProvider"
        description "Update Adyen payment provider"

        input_object_class Types::PaymentProviders::UpdateInput

        type Types::PaymentProviders::Adyen
      end
    end
  end
end
