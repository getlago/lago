# frozen_string_literal: true

module Subscriptions
  module Concerns
    module PlanOverrideConcern
      extend ActiveSupport::Concern

      private

      def ensure_plan_override(params: {})
        current_plan = subscription.plan

        if current_plan.parent_id
          current_plan
        else
          override_result = Plans::OverrideService.call!(
            plan: current_plan,
            params:,
            subscription:
          )
          subscription.update!(plan: override_result.plan)
          override_result.plan
        end
      end
    end
  end
end
