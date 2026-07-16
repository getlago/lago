# frozen_string_literal: true

module Mutations
  module Entitlement
    class RemoveSubscriptionEntitlement < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:update"

      description "Removes a feature entitlement from a subscription"

      argument :subscription_id, ID, required: true

      argument :feature_code, String, required: true

      field :feature_code, String

      def resolve(**args)
        subscription = current_organization.subscriptions.find_by(id: args[:subscription_id])

        result = ::Entitlement::SubscriptionFeatureRemoveService.call(
          subscription:,
          feature_code: args[:feature_code]
        )

        result.success? ? {feature_code: result.feature_code} : result_error(result)
      end
    end
  end
end
