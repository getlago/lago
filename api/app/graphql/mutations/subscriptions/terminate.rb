# frozen_string_literal: true

module Mutations
  module Subscriptions
    class Terminate < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:update"

      graphql_name "TerminateSubscription"
      description "Terminate a Subscription"

      input_object_class Types::Subscriptions::TerminateSubscriptionInput

      type Types::Subscriptions::Object

      def resolve(id:, **args)
        subscription = current_organization.subscriptions.find_by(id:)
        result = ::Subscriptions::TerminateService.call(subscription:, **args.compact)

        result.success? ? result.subscription : result_error(result)
      end
    end
  end
end
