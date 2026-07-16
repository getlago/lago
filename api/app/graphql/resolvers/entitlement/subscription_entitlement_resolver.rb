# frozen_string_literal: true

module Resolvers
  module Entitlement
    class SubscriptionEntitlementResolver < Resolvers::BaseResolver
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:view"

      description "Retrieve an entitlement of a subscriptions"

      argument :feature_code, String, required: true
      argument :subscription_id, ID, required: true

      type Types::Entitlement::SubscriptionEntitlementObject, null: false

      def resolve(subscription_id:, feature_code:)
        subscription = current_organization.subscriptions.find(subscription_id)

        # TODO: Replace this once we have `where` clause on SubscriptionEntitlementQuery
        all_entitlements = ::Entitlement::SubscriptionEntitlement.for_subscription(subscription)
        entitlement = all_entitlements.find { it.code == feature_code }

        entitlement || not_found_error(resource: "entitlement")
      rescue ActiveRecord::RecordNotFound
        not_found_error(resource: "subscription")
      end
    end
  end
end
