# frozen_string_literal: true

module BillableMetrics
  class DeleteEventsJob < ApplicationJob
    queue_as :default

    def perform(metric)
      Events::DeleteForMetricService.call!(billable_metric: metric)
    end
  end
end
