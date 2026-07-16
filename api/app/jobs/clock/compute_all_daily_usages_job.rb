# frozen_string_literal: true

module Clock
  class ComputeAllDailyUsagesJob < ClockJob
    unique :until_executed, on_conflict: :log

    def perform
      DailyUsages::ComputeAllService.call(timestamp: Time.current)
    end
  end
end
