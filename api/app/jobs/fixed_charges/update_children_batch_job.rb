# frozen_string_literal: true

module FixedCharges
  class UpdateChildrenBatchJob < ApplicationJob
    queue_as :low_priority

    def perform(child_ids:, params:, old_parent_attrs:)
      Rails.logger.info("FixedCharges::UpdateChildrenBatchJob - Started the execution for parent fixed charge with ID: #{old_parent_attrs["id"]}")

      fixed_charge = FixedCharge.find_by(id: old_parent_attrs["id"])

      FixedCharges::UpdateChildrenService.call!(
        fixed_charge:,
        params:,
        old_parent_attrs:,
        child_ids:
      )

      Rails.logger.info("FixedCharges::UpdateChildrenBatchJob - Ended the execution for parent fixed charge with ID: #{old_parent_attrs["id"]}")
    end
  end
end
