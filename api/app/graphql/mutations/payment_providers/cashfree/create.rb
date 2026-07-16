# frozen_string_literal: true

module Mutations
  module PaymentProviders
    module Cashfree
      class Create < Base
        REQUIRED_PERMISSION = "organization:integrations:create"

        graphql_name "AddCashfreePaymentProvider"
        description "Add or update Cashfree payment provider"

        input_object_class Types::PaymentProviders::CashfreeInput

        type Types::PaymentProviders::Cashfree
      end
    end
  end
end
