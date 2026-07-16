# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsages::UpdateService do
  subject(:update_service) { described_class.new(lifetime_usage:, params:) }

  let(:lifetime_usage) { create(:lifetime_usage) }
  let(:params) do
    {
      external_historical_usage_amount_cents:
    }
  end
  let(:external_historical_usage_amount_cents) { 20 }

  describe "#call" do
    it "updates the historical usage" do
      result = update_service.call
      expect(result).to be_success

      expect(result.lifetime_usage.historical_usage_amount_cents).to eq(20)
    end

    context "without lifetime_usage" do
      let(:lifetime_usage) { nil }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("lifetime_usage_not_found")
      end
    end

    context "with a negative historical usage amount" do
      let(:external_historical_usage_amount_cents) { -20 }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error.messages[:historical_usage_amount_cents]).to eq(["value_is_out_of_range"])
      end
    end
  end
end
