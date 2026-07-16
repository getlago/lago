# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utils::DeviceInfo do
  describe ".parse" do
    subject(:result) { described_class.parse(request) }

    let(:request) { instance_double(ActionDispatch::Request, user_agent:, remote_ip: "192.168.1.1") }

    context "with a valid User-Agent" do
      let(:user_agent) do
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
        AppleWebKit/537.36 (KHTML, like Gecko) \
        Chrome/120.0.0.0 \
        Safari/537.36"
      end

      it "returns parsed device info" do
        expect(result).to include(
          user_agent: request.user_agent,
          ip_address: "192.168.1.1",
          browser: a_string_including("Chrome"),
          os: a_string_including("Mac"),
          device_type: "desktop"
        )
      end
    end

    context "when request is nil" do
      let(:request) { nil }

      it { is_expected.to be_nil }
    end

    context "when User-Agent is blank" do
      let(:user_agent) { "" }

      it { is_expected.to be_nil }
    end

    context "when User-Agent is nil" do
      let(:user_agent) { nil }

      it { is_expected.to be_nil }
    end
  end
end
