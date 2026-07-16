# frozen_string_literal: true

module Mutations
  module Subscriptions
    class UpdateFixedCharge < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:update"

      graphql_name "UpdateSubscriptionFixedCharge"
      description "Update a fixed charge for a subscription"

      input_object_class Types::Subscriptions::UpdateFixedChargeInput

      type Types::FixedCharges::Object

      def resolve(**args)
        subscription = current_organization.subscriptions.find_by(id: args[:subscription_id])
        fixed_charge = subscription&.plan&.fixed_charges&.find_by(code: args[:fixed_charge_code])

        args[:properties] = args[:properties].to_h if args[:properties]

        result = ::Subscriptions::UpdateOrOverrideFixedChargeService.call(
          subscription:,
          fixed_charge:,
          params: args.except(:subscription_id, :fixed_charge_code)
        )

        result.success? ? result.fixed_charge : result_error(result)
      end
    end
  end
end
