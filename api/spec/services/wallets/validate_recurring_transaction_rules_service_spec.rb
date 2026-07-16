# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::ValidateRecurringTransactionRulesService do
  subject(:validate_service) { described_class.new(result, **args) }

  let(:result) { BaseService::Result.new }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:args) do
    {
      recurring_transaction_rules: rules
    }
  end

  describe ".valid?" do
    context "when there is no recurring transaction rules" do
      let(:args) do
        {}
      end

      it "returns true" do
        expect(validate_service).to be_valid
      end
    end

    context "when there is wrong number of recurring transaction rules" do
      let(:rules) do
        [
          {
            trigger: "interval",
            interval: "monthly",
            paid_credits: "105",
            granted_credits: "105"
          },
          {
            trigger: "threshold",
            threshold_credits: "1.0",
            paid_credits: "105",
            granted_credits: "105"
          }
        ]
      end

      it "returns false and result has errors" do
        expect(validate_service).not_to be_valid
        expect(result.error.messages[:recurring_transaction_rules]).to eq(["invalid_number_of_recurring_rules"])
      end
    end
  end
end
