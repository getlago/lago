# frozen_string_literal: true

module Mutations
  module CustomerPortal
    class GenerateUrl < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      graphql_name "GenerateCustomerPortalUrl"
      description "Generate customer portal URL"

      argument :id, ID, required: true

      field :url, String, null: false

      def resolve(id:)
        customer = current_organization.customers.find_by(id:)
        result = ::CustomerPortal::GenerateUrlService.call(customer:)

        if result.success?
          {url: result.url}
        else
          result_error(result)
        end
      end
    end
  end
end
