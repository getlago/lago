# frozen_string_literal: true

module Resolvers
  module CustomerPortal
    class SubscriptionResolver < Resolvers::BaseResolver
      include AuthenticableCustomerPortalUser

      description "Query a single subscription from the customer portal"

      argument :id, ID, required: true, description: "Uniq ID of the subscription"

      type Types::Subscriptions::Object, null: true

      def resolve(id: nil)
        context[:customer_portal_user].subscriptions.find(id)
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "subscription")
      end
    end
  end
end
