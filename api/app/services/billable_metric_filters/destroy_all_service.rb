# frozen_string_literal: true

module BillableMetricFilters
  class DestroyAllService < BaseService
    Result = BaseResult[:billable_metric]

    def initialize(billable_metric)
      @billable_metric = billable_metric
      super
    end

    def call
      return result unless billable_metric
      return result unless billable_metric.discarded?

      deleted_at = Time.current

      billable_metric.filters.unscope(:order).find_each do |filter|
        # rubocop:disable Rails/SkipsModelValidations
        filter.filter_values.update_all(deleted_at: deleted_at)
        filter.charge_filters.update_all(deleted_at: deleted_at)
        # rubocop:enable Rails/SkipsModelValidations

        filter.discard!
      end

      result.billable_metric = billable_metric
      result
    end

    private

    attr_reader :billable_metric
  end
end
