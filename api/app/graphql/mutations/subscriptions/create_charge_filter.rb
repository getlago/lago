# frozen_string_literal: true

module Mutations
  module Subscriptions
    class CreateChargeFilter < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:update"

      graphql_name "CreateSubscriptionChargeFilter"
      description "Create a charge filter for a subscription"

      input_object_class Types::Subscriptions::CreateChargeFilterInput

      type Types::ChargeFilters::Object

      def resolve(**args)
        subscription = current_organization.subscriptions.find_by(id: args[:subscription_id])
        charge = subscription&.plan&.charges&.find_by(code: args[:charge_code])

        params = args.except(:subscription_id, :charge_code).to_h.deep_symbolize_keys
        params[:properties] = params[:properties].to_h if params[:properties]

        result = ::Subscriptions::ChargeFilters::CreateService.call(
          subscription:,
          charge:,
          params:
        )

        result.success? ? result.charge_filter : result_error(result)
      end
    end
  end
end
