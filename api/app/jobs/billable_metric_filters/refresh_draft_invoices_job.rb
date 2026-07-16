# frozen_string_literal: true

module BillableMetricFilters
  class RefreshDraftInvoicesJob < ApplicationJob
    queue_as :default

    def perform(billable_metric_id)
      billable_metric = BillableMetric.find_by(id: billable_metric_id)
      return unless billable_metric

      Invoice.draft
        .joins(plans: [:billable_metrics])
        .where(billable_metrics: {id: billable_metric.id})
        .distinct
        .in_batches do |batch|
          batch.update_all(ready_to_be_refreshed: true) # rubocop:disable Rails/SkipsModelValidations
        end
    end
  end
end
