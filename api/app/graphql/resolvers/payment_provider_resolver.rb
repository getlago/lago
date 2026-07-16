# frozen_string_literal: true

module Resolvers
  class PaymentProviderResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "organization:integrations:view"

    description "Query a single payment provider"

    argument :code, String, required: false, description: "Code of the payment provider"
    argument :id, ID, required: false, description: "Uniq ID of the payment provider"

    type Types::PaymentProviders::Object, null: true

    def resolve(id: nil, code: nil)
      if id.present?
        current_organization.payment_providers.find(id)
      else
        current_organization.payment_providers.find_by!(code:)
      end
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "payment_provider")
    end
  end
end
