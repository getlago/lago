# frozen_string_literal: true

module Mutations
  module Subscriptions
    class Update < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:update"

      graphql_name "UpdateSubscription"
      description "Update a Subscription"

      input_object_class Types::Subscriptions::UpdateSubscriptionInput

      type Types::Subscriptions::Object

      def resolve(entitlements: nil, **args)
        subscription = current_organization.subscriptions.find_by(id: args[:id])
        result = ::Subscriptions::UpdateService.call(subscription:, params: args)

        result.success? ? subscription.reload : result_error(result)
      end
    end
  end
end
