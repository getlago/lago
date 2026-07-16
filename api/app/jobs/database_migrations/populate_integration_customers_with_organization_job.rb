# frozen_string_literal: true

module DatabaseMigrations
  class PopulateIntegrationCustomersWithOrganizationJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1000

    def perform(batch_number = 1)
      batch = IntegrationCustomers::BaseCustomer.unscoped
        .where(organization_id: nil)
        .limit(BATCH_SIZE)

      if batch.exists?
        # rubocop:disable Rails/SkipsModelValidations
        batch.update_all("organization_id = (SELECT organization_id FROM customers WHERE customers.id = integration_customers.customer_id)")
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
