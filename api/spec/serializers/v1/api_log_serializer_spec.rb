# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::ApiLogSerializer, clickhouse: true do
  subject(:serializer) { described_class.new(api_log, root_name: "api_log") }

  let(:api_log) { create(:clickhouse_api_log) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["api_log"]["request_id"]).to eq(api_log.request_id)
    expect(result["api_log"]["client"]).to eq(api_log.client)
    expect(result["api_log"]["http_method"]).to eq(api_log.http_method)
    expect(result["api_log"]["http_status"]).to eq(api_log.http_status)
    expect(result["api_log"]["request_origin"]).to eq(api_log.request_origin)
    expect(result["api_log"]["request_path"]).to eq(api_log.request_path)
    expect(result["api_log"]["request_body"]).to eq(api_log.request_body)
    expect(result["api_log"]["request_response"]).to eq(api_log.request_response)
    expect(result["api_log"]["api_version"]).to eq(api_log.api_version)
    expect(result["api_log"]["logged_at"]).to eq(api_log.logged_at.iso8601)
    expect(result["api_log"]["created_at"]).to eq(api_log.created_at.iso8601)
  end
end
