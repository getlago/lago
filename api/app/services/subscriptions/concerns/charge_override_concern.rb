# frozen_string_literal: true

module Subscriptions
  module Concerns
    module ChargeOverrideConcern
      extend ActiveSupport::Concern

      private

      def find_or_create_charge_override(target_plan)
        parent_charge = find_parent_charge
        existing_override = target_plan.charges.find_by(parent_id: parent_charge.id)

        if existing_override
          existing_override
        else
          override_result = Charges::OverrideService.call!(
            charge: parent_charge,
            params: {plan_id: target_plan.id}
          )
          override_result.charge
        end
      end

      def find_parent_charge
        if charge.parent_id
          charge.parent
        else
          charge
        end
      end
    end
  end
end
