# frozen_string_literal: true

module Resolvers
  class PaymentResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "payments:view"

    description "Query a single Payment"

    argument :id, ID, required: true, description: "Uniq ID of the payment"

    type Types::Payments::Object, null: true

    def resolve(id:)
      Payment.for_organization(current_organization).find(id)
    rescue ActiveRecord::RecordNotFound
      not_found_error(resource: "payment")
    end
  end
end
