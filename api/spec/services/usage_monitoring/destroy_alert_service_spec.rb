# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::DestroyAlertService do
  describe ".call" do
    subject(:result) { described_class.call(alert:) }

    let(:alert) { create(:alert, thresholds: [1, 2, 50]) }

    it "discards the alert" do
      expect(result).to be_success
      expect(result.alert).to be_discarded
      expect(result.alert.thresholds.count).to eq 0
    end
  end
end
