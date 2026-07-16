# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Moneyhash
      class Update < Base
        REQUIRED_PERMISSION = "organization:integrations:update"

        graphql_name "UpdateMoneyhashPaymentProvider"
        description "Update Moneyhash payment provider"

        input_object_class Types::PaymentProviders::UpdateInput

        type Types::PaymentProviders::Moneyhash
      end
    end
  end
end
