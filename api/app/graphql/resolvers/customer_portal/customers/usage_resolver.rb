# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    module Customers
      class UsageResolver < Resolvers::BaseResolver
        include AuthenticableCustomerPortalUser

        description "Query the usage of the customer on the current billing period"

        argument :subscription_id, type: ID, required: true

        type Types::Customers::Usage::Current, null: false

        def resolve(subscription_id:)
          result = Invoices::CustomerUsageService.with_ids(
            organization_id: context[:customer_portal_user].organization_id,
            customer_id: context[:customer_portal_user].id,
            subscription_id:,
            apply_taxes: false
          ).call

          result.success? ? result.usage : result_error(result)
        rescue ActiveRecord::RecordNotFound
          not_found_error(resource: "customer")
        end
      end
    end
  end
end
