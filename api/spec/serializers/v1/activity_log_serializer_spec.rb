# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::ActivityLogSerializer, clickhouse: true do
  subject(:serializer) { described_class.new(activity_log, root_name: "activity_log") }

  let(:activity_log) { create(:clickhouse_activity_log) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["activity_log"]["activity_id"]).to eq(activity_log.activity_id)
    expect(result["activity_log"]["activity_type"]).to eq(activity_log.activity_type)
    expect(result["activity_log"]["activity_source"]).to eq(activity_log.activity_source)
    expect(result["activity_log"]["activity_object"]).to eq(activity_log.activity_object)
    expect(result["activity_log"]["activity_object_changes"]).to eq(activity_log.activity_object_changes)
    expect(result["activity_log"]["user_email"]).to eq(activity_log.user.email)
    expect(result["activity_log"]["resource_id"]).to eq(activity_log.resource_id)
    expect(result["activity_log"]["resource_type"]).to eq(activity_log.resource_type)
    expect(result["activity_log"]["external_customer_id"]).to eq(activity_log.external_customer_id)
    expect(result["activity_log"]["external_subscription_id"]).to eq(activity_log.external_subscription_id)
    expect(result["activity_log"]["logged_at"]).to eq(activity_log.logged_at.iso8601)
    expect(result["activity_log"]["created_at"]).to eq(activity_log.created_at.iso8601)
  end
end
