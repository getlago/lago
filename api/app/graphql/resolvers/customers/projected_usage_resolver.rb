# frozen_string_literal: true

module Resolvers
  module Customers
    class ProjectedUsageResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "customers:view"

      description "Query the projected usage of the customer on the current billing period"

      argument :customer_id, type: ID, required: false
      argument :subscription_id, type: ID, required: true

      type Types::Customers::Usage::Projected, null: false

      def resolve(customer_id:, subscription_id:)
        result = Invoices::CustomerUsageService.with_ids(
          organization_id: current_organization.id,
          customer_id:,
          subscription_id:,
          apply_taxes: false,
          calculate_projected_usage: true
        ).call

        result.success? ? result.usage : result_error(result)
      end
    end
  end
end
