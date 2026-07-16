# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Flutterwave
      class Create < Base
        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "AddFlutterwavePaymentProvider"
        description "Add Flutterwave payment provider"

        input_object_class Types::PaymentProviders::FlutterwaveInput

        type Types::PaymentProviders::Flutterwave
      end
    end
  end
end
