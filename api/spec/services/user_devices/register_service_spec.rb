# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserDevices::RegisterService do
  subject(:result) { described_class.call(user:, skip_log:) }

  include_context "with mocked security logger"

  let(:membership) { create(:membership) }
  let(:user) { membership.user }
  let(:organization) { membership.organization }
  let(:skip_log) { false }
  let(:device_info) do
    {
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      ip_address: "192.168.1.1",
      browser: "Chrome 120",
      os: "macOS",
      device_type: "desktop"
    }
  end

  before do
    membership
    CurrentContext.device_info = device_info
    allow(organization).to receive(:security_logs_enabled?).and_return(true)
    allow(user).to receive(:active_organizations).and_return([organization])
  end

  context "when device_info is nil" do
    let(:device_info) { nil }

    it "returns result without creating a device" do
      expect { result }.not_to change(UserDevice, :count)
    end
  end

  context "when device is new" do
    it "creates a user device" do
      expect { result }.to change(UserDevice, :count).by(1)

      device = user.user_devices.sole
      expect(device.fingerprint).to eq(Digest::SHA256.hexdigest(device_info[:user_agent]))
      expect(device.browser).to eq("Chrome 120")
      expect(device.os).to eq("macOS")
      expect(device.device_type).to eq("desktop")
      expect(device.last_ip_address).to eq("192.168.1.1")
    end

    it "produces security logs" do
      result

      expect(security_logger).to have_received(:produce).with(
        organization:,
        log_type: "user",
        log_event: "user.new_device_logged_in",
        user:
      )
    end

    context "with skip_log: true" do
      let(:skip_log) { true }

      it "creates a user device" do
        expect { result }.to change(UserDevice, :count).by(1)
      end

      it "does not produce security logs" do
        result

        expect(security_logger).not_to have_received(:produce)
      end
    end
  end

  context "when device is known" do
    let!(:existing_device) do
      create(:user_device,
        user:,
        fingerprint: Digest::SHA256.hexdigest(device_info[:user_agent]),
        last_logged_at: 1.day.ago)
    end

    it "does not create a new device" do
      expect { result }.not_to change(UserDevice, :count)
    end

    it "updates last_logged_at" do
      result

      expect(existing_device.reload.last_logged_at).to be_within(1.second).of(Time.current)
    end

    it "does not produce security logs" do
      result

      expect(security_logger).not_to have_received(:produce)
    end
  end
end
