# frozen_string_literal: true

module Types
  module ActivityLogs
    class ResourceTypeEnum < Types::BaseEnum
      description "Activity Logs resource type enums"

      Clickhouse::ActivityLog::RESOURCE_TYPES.each do |key, value|
        value key, value:, description: value
      end
    end
  end
end
