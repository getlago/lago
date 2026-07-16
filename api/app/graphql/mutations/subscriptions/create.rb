# frozen_string_literal: true

module Mutations
  module Subscriptions
    class Create < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:create"

      graphql_name "CreateSubscription"
      description "Create a new Subscription"

      input_object_class Types::Subscriptions::CreateSubscriptionInput

      type Types::Subscriptions::Object

      def resolve(entitlements: nil, **args)
        customer = current_organization.customers.find_by(id: args[:customer_id])
        plan = current_organization.plans.find_by(id: args[:plan_id])

        result = ::Subscriptions::CreateService.call(
          customer:,
          plan:,
          params: args.merge(external_id: args[:external_id] || SecureRandom.uuid)
        )

        return result_error(result) unless result.success?

        subscription = result.subscription

        result.success? ? subscription.reload : result_error(result)
      end
    end
  end
end
