# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsageMonitoring::CurrentUsageAmountAlert do
  let(:alert) { create(:usage_current_amount_alert) }
  let(:subscription) { create(:subscription) }

  describe "#find_value" do
    it do
      current_usage = double(amount_cents: 100) # rubocop:disable RSpec/VerifiedDoubles
      expect(alert.find_value(current_usage)).to eq(100)
    end
  end
end
