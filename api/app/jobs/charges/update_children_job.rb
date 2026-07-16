# frozen_string_literal: true

module Charges
  class UpdateChildrenJob < ApplicationJob
    queue_as :default

    def perform(params:, old_parent_attrs:, old_parent_applied_pricing_unit_attrs:)
      charge = Charge.find_by(id: old_parent_attrs["id"])
      return unless charge

      charge.children.joins(plan: :subscriptions).where(subscriptions: {status: %w[active pending]}).distinct.pluck(:id).each_slice(20) do |child_ids|
        Charges::UpdateChildrenBatchJob.perform_later(
          child_ids:,
          params:,
          old_parent_attrs:,
          old_parent_applied_pricing_unit_attrs:
        )
      end
    end
  end
end
