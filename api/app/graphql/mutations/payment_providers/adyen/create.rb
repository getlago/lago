# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Adyen
      class Create < Base
        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "AddAdyenPaymentProvider"
        description "Add Adyen payment provider"

        input_object_class Types::PaymentProviders::AdyenInput

        type Types::PaymentProviders::Adyen
      end
    end
  end
end
