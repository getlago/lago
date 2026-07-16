# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    class OrganizationResolver < Resolvers::BaseResolver
      include AuthenticableCustomerPortalUser

      description "Query customer portal organization"

      type Types::CustomerPortal::Organizations::Object, null: true

      def resolve
        context[:customer_portal_user].organization
      end
    end
  end
end
