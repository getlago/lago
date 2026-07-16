# frozen_string_literal: true

module BillableMetrics
  class ExpressionCacheService < CacheService
    CACHE_KEY_VERSION = "1"

    def initialize(organization_id, billable_metric_code)
      @organization_id = organization_id
      @billable_metric_code = billable_metric_code

      super
    end

    def cache_key
      [
        "expression",
        CACHE_KEY_VERSION,
        organization_id,
        billable_metric_code
      ].compact.join("/")
    end

    private

    attr_reader :organization_id, :billable_metric_code
  end
end
