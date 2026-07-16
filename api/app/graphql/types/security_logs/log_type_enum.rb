# frozen_string_literal: true

module Types
  module SecurityLogs
    class LogTypeEnum < Types::BaseEnum
      description "Security Log type"

      Clickhouse::SecurityLog::LOG_TYPES.each do |type|
        value type.tr(".", "_"), value: type, description: type
      end
    end
  end
end
