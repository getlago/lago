# frozen_string_literal: true

module DatabaseMigrations
  class PopulateInvoicesBillingEntitySequentialIdJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1000

    def perform(batch_number = 1)
      batch = Invoice
        .where("organization_sequential_id != 0 AND billing_entity_sequential_id IS NULL")
        .or(Invoice.where("organization_sequential_id != 0 AND billing_entity_sequential_id != organization_sequential_id"))
        .order(:organization_id, :organization_sequential_id)
        .limit(BATCH_SIZE)

      if batch.exists?
        # rubocop:disable Rails/SkipsModelValidations
        batch.update_all("billing_entity_sequential_id = organization_sequential_id")
        # rubocop:enable Rails/SkipsModelValidations

        # Queue the next batch
        self.class.perform_later(batch_number + 1)
      else
        Rails.logger.info("Finished the execution")
      end
    end

    def lock_key_arguments
      [arguments]
    end
  end
end
