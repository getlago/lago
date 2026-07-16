# frozen_string_literal: true

module Charges
  class UpdateChildrenBatchJob < ApplicationJob
    queue_as :low_priority
    retry_on WithAdvisoryLock::FailedToAcquireLock, wait: :polynomially_longer, attempts: 5

    def perform(child_ids:, params:, old_parent_attrs:, old_parent_applied_pricing_unit_attrs:)
      Rails.logger.info("Charges::UpdateChildrenBatchJob - Started the execution for parent charge with ID: #{old_parent_attrs["id"]}")

      charge = Charge.find_by(id: old_parent_attrs["id"])

      Charges::UpdateChildrenService.call!(
        charge:,
        params:,
        old_parent_attrs:,
        old_parent_applied_pricing_unit_attrs:,
        child_ids:
      )

      Rails.logger.info("Charges::UpdateChildrenBatchJob - Ended the execution for parent charge with ID: #{old_parent_attrs["id"]}")
    end
  end
end
