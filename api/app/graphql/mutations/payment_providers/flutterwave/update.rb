# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Flutterwave
      class Update < Base
        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateFlutterwavePaymentProvider"
        description "Update Flutterwave payment provider"

        input_object_class Types::PaymentProviders::UpdateInput

        type Types::PaymentProviders::Flutterwave
      end
    end
  end
end
