# frozen_string_literal: true

module DatabaseMigrations
  class PopulateChargeFilterValuesWithOrganizationJob < ApplicationJob
    queue_as :low_priority
    unique :until_executed

    BATCH_SIZE = 1000

    def perform(batch_number = 1)
      batch = ChargeFilterValue.unscoped
        .where(organization_id: nil)
        .limit(BATCH_SIZE)

      if batch.exists?
        sql = <<-SQL
          organization_id = (
            SELECT billable_metrics.organization_id
            FROM billable_metric_filters
              INNER JOIN billable_metrics ON billable_metric_filters.billable_metric_id = billable_metrics.id
            WHERE billable_metric_filters.id = charge_filter_values.billable_metric_filter_id
          )
        SQL

        batch.update_all(sql) # rubocop:disable Rails/SkipsModelValidations

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
