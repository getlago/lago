# frozen_string_literal: true

module UsageMonitoring
  class BaseService < ::BaseService
    private

    def prepare_thresholds(thresholds, organization_id)
      thresholds.map do |threshold_params|
        {
          organization_id:,
          code: nil,
          recurring: false
        }.merge(threshold_params.to_h)
      end
    end
  end
end
