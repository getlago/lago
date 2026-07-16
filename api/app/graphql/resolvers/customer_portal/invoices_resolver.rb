# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    class InvoicesResolver < Resolvers::BaseResolver
      include AuthenticableCustomerPortalUser

      description "Query invoices of a customer"

      argument :limit, Integer, required: false
      argument :page, Integer, required: false
      argument :search_term, String, required: false
      argument :status, [Types::Invoices::StatusTypeEnum], required: false

      type Types::Invoices::Object.collection_type, null: false

      def resolve(status: nil, page: nil, limit: nil, search_term: nil)
        result = InvoicesQuery.call(
          organization: context[:customer_portal_user],
          pagination: {page:, limit:},
          search_term:,
          filters: {
            customer_id: context[:customer_portal_user].id,
            status:
          }
        )

        return result_error(result) unless result.success?

        Invoice.preload_offset_amounts(result.invoices)
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "customer")
      end
    end
  end
end
