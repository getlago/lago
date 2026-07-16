# frozen_string_literal: true

class EventsChargedInAdvanceConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      Events::PayInAdvanceJob.set(wait: Events::Stores::ClickhouseStore::CLICKHOUSE_MERGE_DELAY).perform_later(message.payload)
    end
  end
end
