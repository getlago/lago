# frozen_string_literal: true

module Types
  module SecurityLogs
    class LogEventEnum < Types::BaseEnum
      description "Security Log event"

      Clickhouse::SecurityLog::LOG_EVENTS.each do |event|
        value event.tr(".", "_"), value: event, description: event
      end
    end
  end
end
