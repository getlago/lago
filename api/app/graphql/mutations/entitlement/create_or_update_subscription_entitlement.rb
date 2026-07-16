# frozen_string_literal: true

module Mutations
  module Entitlement
    class CreateOrUpdateSubscriptionEntitlement < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:update"

      description "Updates a subscription entitlement"

      argument :subscription_id, ID, required: true

      argument :entitlement, Types::Entitlement::EntitlementInput, required: true

      type Types::Entitlement::SubscriptionEntitlementObject

      def resolve(subscription_id:, entitlement: nil)
        subscription = current_organization.subscriptions.find_by(id: subscription_id)

        result = ::Entitlement::SubscriptionEntitlementUpdateService.call(
          subscription:,
          feature_code: entitlement[:feature_code],
          privilege_params: entitlement[:privileges]&.map { [it.privilege_code, it.value] }.to_h,
          partial: false
        )

        result.success? ? result.entitlement : result_error(result)
      end
    end
  end
end
