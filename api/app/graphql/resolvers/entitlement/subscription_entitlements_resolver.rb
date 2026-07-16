# frozen_string_literal: true

module Resolvers
  module Entitlement
    class SubscriptionEntitlementsResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:view"

      description "Query entitlements of a subscriptions"

      argument :subscription_id, ID, required: true

      type Types::Entitlement::SubscriptionEntitlementObject.collection_type, null: false

      def resolve(subscription_id:)
        subscription = current_organization.subscriptions.find(subscription_id)

        ::Entitlement::SubscriptionEntitlement.for_subscription(subscription)
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "subscription")
      end
    end
  end
end
