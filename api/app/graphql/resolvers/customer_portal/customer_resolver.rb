# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    class CustomerResolver < Resolvers::BaseResolver
      include AuthenticableCustomerPortalUser

      description "Query a customer portal user"

      type Types::CustomerPortal::Customers::Object, null: true

      def resolve
        context[:customer_portal_user]
      end
    end
  end
end
