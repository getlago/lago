# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoMcpClient::Config do
  let(:mcp_server_url) { "http://mcp-server:3001/mcp" }
  let(:lago_api_key) { "test_key_123" }

  before do
    stub_const("ENV", ENV.to_h.merge("LAGO_API_URL" => "https://api.lago.dev"))
  end

  describe "#initialize" do
    it "sets server_url, timeout, headers and lago_api_key" do
      config = described_class.new(mcp_server_url:, lago_api_key:)

      expect(config.mcp_server_url).to eq(mcp_server_url)
      expect(config.timeout).to eq(30)
      expect(config.headers).to eq({})
      expect(config.lago_api_key).to eq(lago_api_key)
    end
  end

  describe "#lago_api_url" do
    it "joins the ENV base URL with /api/v1" do
      expect(
        described_class.new(mcp_server_url:, lago_api_key:).lago_api_url
      ).to eq("https://api.lago.dev/api/v1")
    end
  end
end
