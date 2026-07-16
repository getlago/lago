# frozen_string_literal: true

module Mutations
  module PaymentProviders
    class Destroy < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "organization:integrations:delete"

      graphql_name "DestroyPaymentProvider"
      description "Destroy a payment provider"

      argument :id, ID, required: true

      field :id, ID, null: true

      def resolve(id:)
        payment_provider = current_organization.payment_providers.find_by(id:)
        result = ::PaymentProviders::DestroyService.call(payment_provider)

        result.success? ? result.payment_provider : result_error(result)
      end
    end
  end
end
