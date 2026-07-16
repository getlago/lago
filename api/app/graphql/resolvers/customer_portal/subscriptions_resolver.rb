# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    class SubscriptionsResolver < Resolvers::BaseResolver
      include AuthenticableCustomerPortalUser

      description "Query customer portal subscriptions"

      argument :currency, String, required: false
      argument :limit, Integer, required: false
      argument :page, Integer, required: false
      argument :plan_code, String, required: false
      argument :status, [Types::Subscriptions::StatusTypeEnum], required: false

      type Types::Subscriptions::Object.collection_type, null: false

      def resolve(page: nil, limit: nil, plan_code: nil, status: nil, currency: nil)
        result = SubscriptionsQuery.call(
          organization: nil,
          pagination: {page:, limit:},
          filters: {
            external_customer_id: context[:customer_portal_user].external_id,
            plan_code:,
            status:,
            currency:,
            customer: context[:customer_portal_user]
          }
        )

        result.subscriptions
      end
    end
  end
end
