# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::UsageThresholdSerializer do
  subject(:serializer) { described_class.new(usage_threshold, root_name: "usage_threshold") }

  let(:usage_threshold) { create(:usage_threshold) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["usage_threshold"]).to include(
      "lago_id" => usage_threshold.id,
      "threshold_display_name" => usage_threshold.threshold_display_name,
      "amount_cents" => usage_threshold.amount_cents,
      "recurring" => usage_threshold.recurring?,
      "created_at" => usage_threshold.created_at.iso8601,
      "updated_at" => usage_threshold.updated_at.iso8601
    )
  end
end
