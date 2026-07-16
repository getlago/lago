# frozen_string_literal: true

module Mutations
  module Subscriptions
    class UpdateChargeFilter < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:update"

      graphql_name "UpdateSubscriptionChargeFilter"
      description "Update a charge filter for a subscription"

      input_object_class Types::Subscriptions::UpdateChargeFilterInput

      type Types::ChargeFilters::Object

      def resolve(**args)
        subscription = current_organization.subscriptions.find_by(id: args[:subscription_id])
        charge = subscription&.plan&.charges&.find_by(code: args[:charge_code])
        charge_filter = find_charge_filter(charge, args[:values])

        params = args.except(:subscription_id, :charge_code, :values).to_h.deep_symbolize_keys
        params[:properties] = params[:properties].to_h if params[:properties]

        result = ::Subscriptions::ChargeFilters::UpdateOrOverrideService.call(
          subscription:,
          charge:,
          charge_filter:,
          params:
        )

        result.success? ? result.charge_filter : result_error(result)
      end

      private

      def find_charge_filter(charge, values)
        return nil unless charge

        sorted_values = values.sort
        charge.filters.find { |f| f.to_h.sort == sorted_values }
      end
    end
  end
end
