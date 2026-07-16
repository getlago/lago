# frozen_string_literal: true

module Resolvers
  class PaymentMethodsResolver < Resolvers::BaseResolver
    include AuthenticableApiUser
    include RequiredOrganization

    REQUIRED_PERMISSION = "payment_methods:view"

    description "Query payment methods of a customer"

    argument :external_customer_id, ID, required: true, description: "External ID of the customer"
    argument :limit, Integer, required: false
    argument :page, Integer, required: false
    argument :with_deleted, Boolean, required: false

    type Types::PaymentMethods::Object.collection_type, null: false

    def resolve(page: nil, limit: nil, external_customer_id: nil, with_deleted: nil)
      result = PaymentMethodsQuery.call(
        organization: current_organization,
        filters: {
          external_customer_id:,
          with_deleted:
        },
        pagination: {
          page:,
          limit:
        }
      )

      result.payment_methods.includes(:payment_provider)
    end
  end
end
