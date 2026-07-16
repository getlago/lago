# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::EventErrorSerializer do
  subject(:serializer) { described_class.new(event_error, root_name: "event_error") }

  let(:event_error) do
    OpenStruct.new(
      error: {transaction_id: ["value_already_exist"]},
      event: create(:received_event)
    )
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes object" do
    expect(result["event_error"]).to include(
      "status" => 422,
      "error" => "Unprocessable entity",
      "message" => '{"transaction_id":["value_already_exist"]}'
    )

    expect(result["event_error"]["event"]).to include(
      "lago_id" => event_error.event.id,
      "transaction_id" => event_error.event.transaction_id,
      "lago_customer_id" => nil,
      "code" => event_error.event.code,
      "timestamp" => event_error.event.timestamp.iso8601(3),
      "properties" => event_error.event.properties,
      "lago_subscription_id" => nil,
      "external_subscription_id" => event_error.event.external_subscription_id,
      "created_at" => event_error.event.created_at.iso8601
    )
  end
end
