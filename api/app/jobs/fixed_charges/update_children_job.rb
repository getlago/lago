# frozen_string_literal: true

module FixedCharges
  class UpdateChildrenJob < ApplicationJob
    queue_as :default

    def perform(params:, old_parent_attrs:)
      fixed_charge = FixedCharge.find_by(id: old_parent_attrs["id"])
      return unless fixed_charge

      fixed_charge.children.joins(plan: :subscriptions).where(subscriptions: {status: %w[active pending]}).distinct.pluck(:id).each_slice(20) do |child_ids|
        FixedCharges::UpdateChildrenBatchJob.perform_later(
          child_ids:,
          params:,
          old_parent_attrs:
        )
      end
    end
  end
end
