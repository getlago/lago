# frozen_String_literal: true

require "rails_helper"

RSpec.describe V1::AppliedUsageThresholdSerializer do
  subject(:serializer) { described_class.new(applied_usage_threshold, root_name: "applied_usage_threshold") }

  let(:applied_usage_threshold) { create(:applied_usage_threshold) }

  it "serialize the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["applied_usage_threshold"]).to include(
      "lifetime_usage_amount_cents" => applied_usage_threshold.lifetime_usage_amount_cents,
      "created_at" => applied_usage_threshold.created_at.iso8601
    )

    expect(result["applied_usage_threshold"]["usage_threshold"]).to include(
      "lago_id" => applied_usage_threshold.usage_threshold.id,
      "threshold_display_name" => applied_usage_threshold.usage_threshold.threshold_display_name,
      "amount_cents" => applied_usage_threshold.usage_threshold.amount_cents,
      "recurring" => applied_usage_threshold.usage_threshold.recurring
    )
  end
end
