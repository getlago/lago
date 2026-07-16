# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::ApplicableUsageThresholdSerializer do
  subject(:serializer) { described_class.new(usage_threshold, root_name: "applicable_usage_threshold") }

  let(:usage_threshold) { create(:usage_threshold) }

  it "serializes the object without lago_id, created_at, and updated_at" do
    result = JSON.parse(serializer.to_json)

    expect(result["applicable_usage_threshold"]).to eq(
      "threshold_display_name" => usage_threshold.threshold_display_name,
      "amount_cents" => usage_threshold.amount_cents,
      "recurring" => usage_threshold.recurring?
    )
  end
end
