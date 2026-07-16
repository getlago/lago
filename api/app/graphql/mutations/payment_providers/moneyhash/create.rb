# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Moneyhash
      class Create < Base
        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "AddMoneyhashPaymentProvider"
        description "Add Moneyhash payment provider"

        input_object_class Types::PaymentProviders::MoneyhashInput

        type Types::PaymentProviders::Moneyhash
      end
    end
  end
end
