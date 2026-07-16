# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::EventSerializer do
  subject(:serializer) { described_class.new(event, root_name: "event") }

  let(:event) do
    create(
      :event,
      customer_id: nil,
      subscription_id: nil,
      precise_total_amount_cents: "123.6",
      properties: {
        item_value: "12"
      }
    )
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the event" do
    expect(result["event"]).to include(
      "lago_id" => event.id,
      "transaction_id" => event.transaction_id,
      "lago_customer_id" => event.customer_id,
      "code" => event.code,
      "timestamp" => event.timestamp.iso8601(3),
      "precise_total_amount_cents" => "123.6",
      "properties" => event.properties,
      "lago_subscription_id" => event.subscription_id,
      "external_subscription_id" => event.external_subscription_id,
      "created_at" => event.created_at.iso8601
    )
  end
end
