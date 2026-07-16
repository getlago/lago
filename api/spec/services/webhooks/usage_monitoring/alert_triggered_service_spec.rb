# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::UsageMonitoring::AlertTriggeredService do
  subject(:webhook_service) { described_class.new(object: triggered_alert) }

  let(:triggered_alert) { create(:triggered_alert) }

  describe ".call" do
    it_behaves_like "creates webhook", "alert.triggered", "triggered_alert"
  end
end
