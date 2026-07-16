# frozen_string_literal: true

module Clock
  module ApiKeys
    class TrackUsageJob < ClockJob
      def perform
        ::ApiKeys::TrackUsageService.call
      end
    end
  end
end
