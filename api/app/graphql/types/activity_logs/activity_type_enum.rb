# frozen_string_literal: true

module Types
  module ActivityLogs
    class ActivityTypeEnum < Types::BaseEnum
      description "Activity Logs type enums"

      Clickhouse::ActivityLog::ACTIVITY_TYPES.each do |key, value|
        value key, value:, description: value
      end
    end
  end
end
