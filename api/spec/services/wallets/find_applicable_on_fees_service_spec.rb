# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::FindApplicableOnFeesService do
  describe ".call" do
    subject(:result) { described_class.call(allocation_rules:, fee:, customer_id:, fee_targeting_wallets_enabled:) }

    let(:fee_targeting_wallets_enabled) { nil }
    let(:customer_id) { nil }

    context "when there are applicable wallets for billable metrics, fee types and unrestricted" do
      let(:allocation_rules) do
        {
          bm_map: {
            SecureRandom.uuid => [SecureRandom.uuid, SecureRandom.uuid]
          },
          type_map: {
            "charge" => [SecureRandom.uuid, SecureRandom.uuid],
            "commitment" => [SecureRandom.uuid, SecureRandom.uuid]
          },
          unrestricted: [SecureRandom.uuid, SecureRandom.uuid]
        }
      end

      context "when fee matches by billable metric" do
        let(:fee) { create(:charge_fee) }
        let(:bm) { fee.charge.billable_metric }
        let(:matching_wallet_id) { allocation_rules[:bm_map][bm.id].first }

        before do
          allocation_rules[:bm_map][bm.id] = [SecureRandom.uuid, SecureRandom.uuid]
        end

        it "returns matching by billable metric wallet" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq matching_wallet_id
        end
      end

      context "when fee matches by fee type" do
        let(:fee) { create(:minimum_commitment_fee) }
        let(:matching_wallet_id) { allocation_rules[:type_map]["commitment"].first }

        it "returns matching by fee type wallet" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq matching_wallet_id
        end
      end

      context "when fee does not match by billable metric or fee type" do
        let(:fee) { create(:add_on_fee) }
        let(:matching_wallet_id) { allocation_rules[:unrestricted].first }

        it "returns unrestricted wallet" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq matching_wallet_id
        end
      end
    end

    context "when there are applicable wallets only for fee types and unrestricted" do
      let(:allocation_rules) do
        {
          bm_map: {},
          type_map: {
            "charge" => [SecureRandom.uuid, SecureRandom.uuid],
            "commitment" => [SecureRandom.uuid, SecureRandom.uuid]
          },
          unrestricted: [SecureRandom.uuid, SecureRandom.uuid]
        }
      end

      context "when fee matches by fee type" do
        let(:fee) { create(:minimum_commitment_fee) }
        let(:matching_wallet_id) { allocation_rules[:type_map]["commitment"].first }

        it "returns matching by fee type wallet" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq matching_wallet_id
        end
      end

      context "when fee does not match by fee type" do
        let(:fee) { create(:add_on_fee) }
        let(:matching_wallet_id) { allocation_rules[:unrestricted].first }

        it "returns unrestricted wallet" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq matching_wallet_id
        end
      end
    end

    context "when there are applicable wallets only for fee types" do
      let(:fee) { create(:fee, fee_type: "subscription") }

      let(:allocation_rules) do
        {
          bm_map: {},
          type_map: {
            "subscription" => [SecureRandom.uuid, SecureRandom.uuid],
            "charge" => [SecureRandom.uuid, SecureRandom.uuid]
          },
          unrestricted: []
        }
      end

      context "when fee matches by fee type" do
        let(:fee) { create(:fee, fee_type: "subscription") }
        let(:matching_wallet_id) { allocation_rules[:type_map]["subscription"].first }

        it "returns matching by fee type wallet" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq matching_wallet_id
        end
      end

      context "when fee does not match by fee type" do
        let(:fee) { create(:add_on_fee) }

        it "returns nil" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to be nil
        end
      end
    end

    context "when there are no applicable wallets" do
      let(:fee) { create(:fee) }

      let(:allocation_rules) do
        {
          bm_map: {},
          type_map: {},
          unrestricted: []
        }
      end

      it "returns nil" do
        expect(result).to be_success
        expect(result.top_priority_wallet).to be_nil
      end
    end

    context "when fee has target_wallet_code in grouped_by", :premium do
      let(:customer) { create(:customer, organization:) }
      let(:invoice) { create(:invoice, customer:, organization:) }
      let(:subscription) { create(:subscription, customer:) }
      let(:wallet) { create(:wallet, customer:, code: "target_wallet") }
      let(:charge) { create(:standard_charge, organization:, accepts_target_wallet:) }
      let(:accepts_target_wallet) { nil }
      let(:customer_id) { customer.id }
      let(:fee) do
        create(:charge_fee, invoice:, subscription:, charge:,
          grouped_by: {"target_wallet_code" => "target_wallet"})
      end

      let(:allocation_rules) do
        {
          bm_map: {},
          type_map: {},
          unrestricted: [SecureRandom.uuid, SecureRandom.uuid]
        }
      end

      before { wallet }

      context "when fee_targeting_wallets_enabled is true" do
        let(:fee_targeting_wallets_enabled) { true }
        let(:organization) { create(:organization, premium_integrations: ["events_targeting_wallets"]) }

        context "when charge accepts target wallet" do
          let(:accepts_target_wallet) { true }

          it "returns the wallet matching target_wallet_code" do
            expect(result).to be_success
            expect(result.top_priority_wallet).to eq(wallet.id)
          end

          context "when target wallet does not exist" do
            let(:fee) do
              create(:charge_fee, invoice:, subscription:, charge:,
                grouped_by: {"target_wallet_code" => "nonexistent"})
            end

            it "falls back to allocation rules" do
              expect(result).to be_success
              expect(result.top_priority_wallet).to eq(allocation_rules[:unrestricted].first)
            end
          end

          context "when target wallet exists but is not active" do
            before { wallet.update!(status: :terminated) }

            it "falls back to allocation rules" do
              expect(result).to be_success
              expect(result.top_priority_wallet).to eq(allocation_rules[:unrestricted].first)
            end
          end

          context "when target_wallet_code takes priority over billable metric wallets" do
            let(:allocation_rules) do
              {
                bm_map: {fee.charge.billable_metric_id => [SecureRandom.uuid]},
                type_map: {},
                unrestricted: []
              }
            end

            it "returns the wallet matching target_wallet_code" do
              expect(result).to be_success
              expect(result.top_priority_wallet).to eq(wallet.id)
            end
          end
        end

        context "when charge does not accept target wallet" do
          let(:accepts_target_wallet) { false }

          it "ignores target_wallet_code and falls back to allocation rules" do
            expect(result).to be_success
            expect(result.top_priority_wallet).to eq(allocation_rules[:unrestricted].first)
          end
        end
      end

      context "when fee_targeting_wallets_enabled is false" do
        let(:fee_targeting_wallets_enabled) { false }
        let(:accepts_target_wallet) { false }
        let(:organization) { create(:organization, premium_integrations: []) }

        it "ignores target_wallet_code and falls back to allocation rules" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq(allocation_rules[:unrestricted].first)
        end
      end
    end

    context "when wallet_currencies is present in allocation rules" do
      let(:usd_wallet_id) { SecureRandom.uuid }
      let(:eur_wallet_id) { SecureRandom.uuid }

      let(:allocation_rules) do
        {
          bm_map: {},
          type_map: {},
          unrestricted: [eur_wallet_id, usd_wallet_id],
          wallet_currencies: {
            eur_wallet_id => "EUR",
            usd_wallet_id => "USD"
          }
        }
      end

      context "when fee currency matches a wallet" do
        let(:fee) { create(:add_on_fee, amount_currency: "USD") }

        it "returns the wallet matching the fee currency" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq(usd_wallet_id)
        end
      end

      context "when fee currency matches the higher-priority wallet" do
        let(:fee) { create(:add_on_fee, amount_currency: "EUR") }

        it "returns the higher-priority wallet" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq(eur_wallet_id)
        end
      end

      context "when fee currency does not match any wallet" do
        let(:fee) { create(:add_on_fee, amount_currency: "GBP") }

        it "returns nil" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to be_nil
        end
      end

      context "when filtering applies to billable metric wallets" do
        let(:fee) { create(:charge_fee, amount_currency: "USD") }
        let(:bm_id) { fee.charge.billable_metric_id }

        let(:allocation_rules) do
          {
            bm_map: {bm_id => [eur_wallet_id, usd_wallet_id]},
            type_map: {},
            unrestricted: [],
            wallet_currencies: {
              eur_wallet_id => "EUR",
              usd_wallet_id => "USD"
            }
          }
        end

        it "returns the wallet matching the fee currency" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq(usd_wallet_id)
        end
      end

      context "when filtering applies to fee type wallets" do
        let(:fee) { create(:charge_fee, amount_currency: "USD") }

        let(:allocation_rules) do
          {
            bm_map: {},
            type_map: {"charge" => [eur_wallet_id, usd_wallet_id]},
            unrestricted: [],
            wallet_currencies: {
              eur_wallet_id => "EUR",
              usd_wallet_id => "USD"
            }
          }
        end

        it "returns the wallet matching the fee currency" do
          expect(result).to be_success
          expect(result.top_priority_wallet).to eq(usd_wallet_id)
        end
      end
    end
  end
end
