# frozen_string_literal: true

module Charges
  class CreateChildrenJob < ApplicationJob
    queue_as "default"

    def perform(charge:, payload:)
      plan = charge.plan
      return unless plan&.children&.any?

      plan.children.joins(:subscriptions).where(subscriptions: {status: %w[active pending]}).distinct.pluck(:id).each_slice(20) do |child_ids|
        Charges::CreateChildrenBatchJob.perform_later(
          child_ids:,
          charge:,
          payload:
        )
      end
    end
  end
end
