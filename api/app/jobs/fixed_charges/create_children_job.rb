# frozen_string_literal: true

module FixedCharges
  class CreateChildrenJob < ApplicationJob
    queue_as "default"

    def perform(fixed_charge:, payload:)
      plan = fixed_charge.plan
      return unless plan&.children&.any?

      plan.children.joins(:subscriptions).where(subscriptions: {status: %w[active pending]}).distinct.pluck(:id).each_slice(20) do |child_ids|
        FixedCharges::CreateChildrenBatchJob.perform_later(
          child_ids:,
          fixed_charge:,
          payload:
        )
      end
    end
  end
end
