# frozen_string_literal: true

module BillableMetricFilters
  class DestroyAllJob < ApplicationJob
    queue_as :low_priority

    def perform(billable_metric_id)
      billable_metric = BillableMetric.with_discarded.find_by(id: billable_metric_id)
      BillableMetricFilters::DestroyAllService.call!(billable_metric)
    end
  end
end
