# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Subscriptions::ActivationRuleSerializer do
  subject(:serializer) { described_class.new(activation_rule, root_name: "activation_rule") }

  let(:activation_rule) { create(:subscription_activation_rule) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["activation_rule"]).to include(
      "lago_id" => activation_rule.id,
      "type" => Subscription::ActivationRule::TYPES[:payment],
      "timeout_hours" => activation_rule.timeout_hours,
      "status" => activation_rule.status,
      "expires_at" => nil,
      "created_at" => activation_rule.created_at.iso8601,
      "updated_at" => activation_rule.updated_at.iso8601
    )
  end

  context "when expires_at is set" do
    let(:expires_at) { Time.zone.parse("2026-04-13T10:00:00Z") }
    let(:activation_rule) { create(:subscription_activation_rule, expires_at:) }

    it "serializes expires_at as iso8601" do
      result = JSON.parse(serializer.to_json)

      expect(result["activation_rule"]["expires_at"]).to eq(expires_at.iso8601)
    end
  end
end
