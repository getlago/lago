# frozen_string_literal: true

module FixedCharges
  class CascadePlanUpdateJob < ApplicationJob
    queue_as :default

    def perform(plan:, cascade_fixed_charges_payload:, timestamp:)
      plan.children.joins(:subscriptions)
        .where(subscriptions: {status: %w[active pending]}).distinct
        .find_in_batches do |child_plans|
          jobs = child_plans.map do |child_plan|
            FixedCharges::CascadeChildPlanUpdateJob.new(
              plan: child_plan,
              cascade_fixed_charges_payload:,
              timestamp:
            )
          end

          ApplicationJob.perform_all_later(jobs)
      end
    end
  end
end
