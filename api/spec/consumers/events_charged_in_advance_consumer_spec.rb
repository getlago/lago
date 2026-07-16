# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventsChargedInAdvanceConsumer do
  subject(:consumer) { karafka.consumer_for(ENV["LAGO_KAFKA_EVENTS_CHARGED_IN_ADVANCE_TOPIC"]) }

  let(:event) { build(:common_event) }

  before { karafka.produce(event.to_json) }

  it "enqueues a pay in advance job with a delay" do
    freeze_time do
      expect { consumer.consume }.to have_enqueued_job(Events::PayInAdvanceJob)
        .with(event.as_json)
        .at(Events::Stores::ClickhouseStore::CLICKHOUSE_MERGE_DELAY.from_now)
    end
  end
end
