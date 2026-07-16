# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::BuildAllocationRulesService do
  describe ".call" do
    subject(:result) { described_class.call(customer:) }

    let(:allocation_rules) { result.allocation_rules }
    let(:bm_map) { allocation_rules[:bm_map] }
    let(:type_map) { allocation_rules[:type_map] }
    let(:unrestricted) { allocation_rules[:unrestricted] }

    let(:wallet_currencies) { allocation_rules[:wallet_currencies] }

    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }

    context "when customer has no wallets" do
      it "returns empty allocation rules" do
        expect(result).to be_success

        expect(bm_map).to eq({})
        expect(type_map).to eq({})
        expect(unrestricted).to eq([])
        expect(wallet_currencies).to eq({})
      end
    end

    context "with a mix of unrestricted, fee type, and metric-targeted wallets" do
      let(:bm1) { create(:billable_metric, organization:) }
      let(:bm2) { create(:billable_metric, organization:) }

      let!(:w_bm2) { create(:wallet, customer:, organization:, currency: "USD", priority: 6) }
      let!(:w_charge) { create(:wallet, customer:, organization:, currency: "EUR", priority: 2, allowed_fee_types: ["charge"]) }
      let!(:w_bm1) { create(:wallet, customer:, organization:, currency: "USD", priority: 4) }
      let!(:w_subscription) { create(:wallet, customer:, organization:, currency: "EUR", priority: 3, allowed_fee_types: ["subscription"]) }
      let!(:w_unres_low) { create(:wallet, customer:, organization:, currency: "EUR", priority: 5) }
      let!(:w_unres_high) { create(:wallet, customer:, organization:, currency: "USD", priority: 1) }

      before do
        create(:wallet_target, wallet: w_bm1, billable_metric: bm1, organization:)
        create(:wallet_target, wallet: w_bm2, billable_metric: bm2, organization:)
      end

      it "builds allocation rules ordered by wallet priority" do
        expect(result).to be_success

        # Unrestricted wallets apply everywhere and keep priority order
        expect(unrestricted).to eq([w_unres_high.id, w_unres_low.id])

        # Fee type map contains wallets that allow the fee type, and unrestricted
        expect(type_map.keys).to match_array(["charge", "subscription"])

        expect(type_map["charge"]).to eq([w_unres_high.id, w_charge.id, w_unres_low.id])
        expect(type_map["subscription"]).to eq([w_unres_high.id, w_subscription.id, w_unres_low.id])

        # Billable metric map is built combining charge wallets, unrestricted wallets and targeted wallet
        expect(bm_map.keys).to match_array([bm1.id, bm2.id])

        expect(bm_map[bm1.id]).to eq([w_unres_high.id, w_charge.id, w_bm1.id, w_unres_low.id])
        expect(bm_map[bm2.id]).to eq([w_unres_high.id, w_charge.id, w_unres_low.id, w_bm2.id])

        # Wallet currencies map all active wallets to their currency
        expect(wallet_currencies).to eq(
          w_unres_high.id => w_unres_high.balance_currency,
          w_charge.id => w_charge.balance_currency,
          w_subscription.id => w_subscription.balance_currency,
          w_bm1.id => w_bm1.balance_currency,
          w_unres_low.id => w_unres_low.balance_currency,
          w_bm2.id => w_bm2.balance_currency
        )
      end
    end

    context "with only unrestricted wallets" do
      let!(:wallet_priority_50) { create(:wallet, customer:, organization:, priority: 50) }
      let!(:wallet_priority_5_newer) { create(:wallet, customer:, organization:, priority: 5, created_at: 2.minutes.ago) }
      let!(:wallet_priority_5_older) { create(:wallet, customer:, organization:, priority: 5, created_at: 5.minutes.ago) }
      let!(:wallet_priority_1) { create(:wallet, customer:, organization:, priority: 1) }

      it "returns unrestricted list and empty maps" do
        expect(result).to be_success
        expect(type_map).to eq({})
        expect(bm_map).to eq({})

        expect(unrestricted).to eq(
          [
            wallet_priority_1.id,
            wallet_priority_5_older.id,
            wallet_priority_5_newer.id,
            wallet_priority_50.id
          ]
        )

        expect(wallet_currencies).to eq(
          wallet_priority_1.id => wallet_priority_1.balance_currency,
          wallet_priority_5_older.id => wallet_priority_5_older.balance_currency,
          wallet_priority_5_newer.id => wallet_priority_5_newer.balance_currency,
          wallet_priority_50.id => wallet_priority_50.balance_currency
        )
      end
    end
  end
end
