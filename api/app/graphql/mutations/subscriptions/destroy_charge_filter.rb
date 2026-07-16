# frozen_string_literal: true

module Mutations
  module Subscriptions
    class DestroyChargeFilter < BaseMutation
      include AuthenticableApiUser
      include RequiredOrganization

      REQUIRED_PERMISSION = "subscriptions:update"

      graphql_name "DestroySubscriptionChargeFilter"
      description "Destroy a charge filter for a subscription"

      input_object_class Types::Subscriptions::DestroyChargeFilterInput

      type Types::ChargeFilters::Object

      def resolve(**args)
        subscription = current_organization.subscriptions.find_by(id: args[:subscription_id])
        charge = subscription&.plan&.charges&.find_by(code: args[:charge_code])
        charge_filter = find_charge_filter(charge, args[:values])

        result = ::Subscriptions::ChargeFilters::DestroyService.call(
          subscription:,
          charge:,
          charge_filter:
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
