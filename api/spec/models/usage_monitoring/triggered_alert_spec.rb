# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::TriggeredAlert do
  let(:triggered_alert) { create(:triggered_alert) }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:subscription).optional
      expect(subject).to belong_to(:wallet).optional
      expect(subject).to belong_to(:alert).class_name("UsageMonitoring::Alert")
        .with_foreign_key(:usage_monitoring_alert_id)
    end
  end
end
