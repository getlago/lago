# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::SecurityLogSerializer, clickhouse: true do
  subject(:serializer) { described_class.new(security_log, root_name: "security_log") }

  let(:security_log) { create(:clickhouse_security_log) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    aggregate_failures do
      expect(result["security_log"]["log_id"]).to eq(security_log.log_id)
      expect(result["security_log"]["log_type"]).to eq(security_log.log_type)
      expect(result["security_log"]["log_event"]).to eq(security_log.log_event)
      expect(result["security_log"]["user_email"]).to eq(security_log.user.email)
      expect(result["security_log"]["logged_at"]).to eq(security_log.logged_at.iso8601)
      expect(result["security_log"]["created_at"]).to eq(security_log.created_at.iso8601)
      expect(result["security_log"]["resources"]).to eq(security_log.resources)
      expect(result["security_log"]["device_info"]).to eq(security_log.device_info)
    end
  end
end
