# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credits::AllocatePrepaidCreditsByWalletsService do
  let(:invoice) do
    create(
      :invoice,
      customer:,
      currency: "EUR",
      total_amount_cents: amount_cents
    )
  end
  let(:fee) {
    create(:charge_fee, invoice:, subscription:,
      amount_cents: fee_amount_cents, precise_amount_cents: fee_amount_cents,
      taxes_precise_amount_cents: 0)
  }
  let(:amount_cents) { 100 }
  let(:fee_amount_cents) { 100 }

  let(:normal_wallet) do
    create(:wallet, :with_inbound_transaction, name: "normal", customer:, balance_cents: 1000, credits_balance: 10.0)
  end

  let(:priority_wallet) do
    create(:wallet, :with_inbound_transaction, name: "priority", customer:, balance_cents: 1000, credits_balance: 10.0, priority: 49)
  end

  let(:limited_charge_wallet) do
    create(:wallet, :with_inbound_transaction, name: "limited charge", customer:, balance_cents: 1000, credits_balance: 10.0, allowed_fee_types: %w[charge])
  end

  let(:priority_limited_charge_wallet) do
    create(:wallet, :with_inbound_transaction, name: "priority limited charge", customer:, balance_cents: 1000, credits_balance: 10.0, priority: 49, allowed_fee_types: %w[charge])
  end

  let(:limited_subscription_wallet) do
    create(:wallet, :with_inbound_transaction, name: "limited subscription", customer:, balance_cents: 1000, credits_balance: 10.0, allowed_fee_types: %w[subscription])
  end

  let(:priority_limited_subscription_wallet) do
    create(:wallet, :with_inbound_transaction, name: "priority limited subscription", customer:, balance_cents: 1000, credits_balance: 10.0, priority: 49, allowed_fee_types: %w[subscription])
  end
  let(:wallets) do
    [
      normal_wallet,
      priority_wallet,
      limited_charge_wallet,
      priority_limited_charge_wallet,
      limited_subscription_wallet,
      priority_limited_subscription_wallet
    ]
  end
  let(:customer) { create(:customer) }
  let(:subscription) { create(:subscription, customer:) }

  before do
    wallets
    fee
    subscription
  end

  describe "#call" do
    subject(:result) { described_class.call(invoice:) }

    it "returns the calculated allocation as wallet_transactions hash" do
      expect(result).to be_success
      expect(result.wallet_transactions).to eq({priority_wallet => 100})
    end

    it "does not persist anything or take side-effects" do
      allow(Customers::LockService).to receive(:call)
      allow(Wallets::Balance::DecreaseService).to receive(:call)
      allow(WalletTransactions::TrackConsumptionService).to receive(:call!)

      expect { subject }.not_to change(WalletTransaction, :count)
      expect(SendWebhookJob).not_to have_been_enqueued

      expect(Customers::LockService).not_to have_received(:call)
      expect(Wallets::Balance::DecreaseService).not_to have_received(:call)
      expect(WalletTransactions::TrackConsumptionService).not_to have_received(:call!)
      expect(priority_wallet.reload.balance_cents).to eq(1000)
    end

    context "when customer has no applicable wallets" do
      let(:wallets) { [] }

      it "returns success with an empty hash" do
        expect(result).to be_success
        expect(result.wallet_transactions).to eq({})
      end
    end

    context "when priority wallet credits are less than invoice amount" do
      let(:amount_cents) { 1500 }
      let(:fee_amount_cents) { 1500 }

      it "drains priority wallets first, then lower-priority wallets" do
        expect(result).to be_success
        expect(result.wallet_transactions).to eq({
          priority_wallet => 1000,
          priority_limited_charge_wallet => 500
        })
      end
    end

    context "with fee type limitations" do
      let(:subscription_fees) { [fee, fee2] }
      let(:amount_cents) { 110 }
      let(:fee) { create(:fee, invoice:, subscription:, amount_cents: 60, precise_amount_cents: 60, taxes_precise_amount_cents: 6) }
      let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 40, precise_amount_cents: 40, taxes_precise_amount_cents: 4) }

      before { subscription_fees }

      it "applies a single unrestricted wallet against the full invoice" do
        expect(result).to be_success
        expect(result.wallet_transactions).to eq({priority_wallet => 110})
      end

      context "when wallet credits are less than invoice amount" do
        let(:amount_cents) { 5150 }
        let(:fee) { create(:fee, invoice:, subscription:, amount_cents: 3500, precise_amount_cents: 3500, taxes_precise_amount_cents: 100) }
        let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 1500, precise_amount_cents: 1500, taxes_precise_amount_cents: 50) }

        it "splits across all wallets honoring fee_type restrictions" do
          expect(result).to be_success
          expect(result.wallet_transactions).to eq({
            priority_wallet => 1000,
            priority_limited_charge_wallet => 1000,
            priority_limited_subscription_wallet => 1000,
            normal_wallet => 1000,
            limited_charge_wallet => 550,
            limited_subscription_wallet => 600
          })
        end
      end
    end

    context "with billable metric limitations" do
      let(:limited_bm_wallet) do
        create(:wallet, :with_inbound_transaction, name: "limited bm wallet", customer:, balance_cents: 1000, credits_balance: 10.0)
      end
      let(:priority_limited_bm_wallet) do
        create(:wallet, :with_inbound_transaction, name: "priority limited bm wallet", customer:, balance_cents: 1000, credits_balance: 10.0, priority: 49)
      end
      let(:wallets) do
        [
          normal_wallet,
          limited_subscription_wallet,
          priority_limited_subscription_wallet,
          limited_bm_wallet,
          priority_limited_bm_wallet,
          priority_limited_charge_wallet,
          priority_wallet,
          limited_charge_wallet
        ]
      end
      let(:subscription_fees) { [fee, fee2] }
      let(:amount_cents) { 110 }
      let(:fee) { create(:fee, invoice:, subscription:, amount_cents: 60, precise_amount_cents: 60, taxes_precise_amount_cents: 6) }
      let(:fee2) { create(:charge_fee, invoice:, subscription:, amount_cents: 40, precise_amount_cents: 40, taxes_precise_amount_cents: 4, charge:) }
      let(:charge) { create(:standard_charge, organization: wallets.first.organization, billable_metric:) }
      let(:billable_metric) { create(:billable_metric, organization: wallets.first.organization) }

      before do
        subscription_fees
        create(:wallet_target, wallet: limited_bm_wallet, billable_metric:)
        create(:wallet_target, wallet: priority_limited_bm_wallet, billable_metric:)
      end

      it "honors wallet_targets, splitting consumption per fee key" do
        expect(result).to be_success
        expect(result.wallet_transactions).to eq({
          priority_limited_subscription_wallet => 66,
          priority_limited_bm_wallet => 44
        })
      end

      context "when precise fees have decimals and is not matching invoice.total_amount_cents" do
        # invoice.total_amount_cents is 114
        let(:amount_cents) { 114.4 }
        let(:subscription_fees) { [fee2] }

        let(:fee2) do
          create(
            :charge_fee,
            invoice:,
            subscription:,
            amount_cents: 44,
            precise_amount_cents: 44,
            taxes_precise_amount_cents: 4.4,
            charge:
          )
        end

        it "rounds the decimals" do
          expect(result).to be_success
          expect(result.wallet_transactions.values.sum).to eq(114)
        end
      end
    end

    context "when wallet is limited to a fee processed last" do
      let(:fee) { nil }
      let(:amount_cents) { 680 }

      let(:wallet_limited_billable_metric) { create(:billable_metric, organization: customer.organization) }
      let(:bm_wallet) do
        create(:wallet, :with_inbound_transaction, customer:, balance_cents: 66, credits_balance: 0.66)
      end
      let(:wallets) { [bm_wallet] }

      before do
        uuid = SecureRandom.uuid
        10.times do |i|
          billable_metric = (i == 9) ? wallet_limited_billable_metric : create(:billable_metric, organization: customer.organization)
          charge = create(:standard_charge, organization: customer.organization, billable_metric: billable_metric)
          create(
            :charge_fee,
            id: "#{uuid[..-2]}#{i}",
            invoice:,
            subscription:,
            charge:,
            amount_cents: 60, precise_amount_cents: 60,
            taxes_precise_amount_cents: 8.456, taxes_amount_cents: 8
          )
        end
        create(:wallet_target, wallet: bm_wallet, billable_metric: wallet_limited_billable_metric)
      end

      it "applies credits based on fee cap, not fee processing order" do
        expect(result).to be_success
        expect(result.wallet_transactions.size).to eq(1)
        expect(result.wallet_transactions[bm_wallet]).to eq(66)
      end
    end

    context "when precise tax rounding causes fee caps to be slightly below invoice total" do
      let(:normal_wallet) do
        create(:wallet, :with_inbound_transaction, name: "normal", customer:, balance_cents: 200_000, credits_balance: 2000.0)
      end
      let(:wallets) { [normal_wallet] }
      let(:amount_cents) { 106_826 }
      let(:fee) { nil }

      before do
        create(:charge_fee, invoice:, subscription:,
          amount_cents: 50_000, precise_amount_cents: 50_000,
          taxes_amount_cents: 3413, taxes_precise_amount_cents: BigDecimal("3412.7"))
        create(:charge_fee, invoice:, subscription:,
          amount_cents: 50_000, precise_amount_cents: 50_000,
          taxes_amount_cents: 3413, taxes_precise_amount_cents: BigDecimal("3412.7"))
      end

      it "applies the full invoice amount without a rounding gap" do
        expect(result).to be_success
        expect(result.wallet_transactions.values.sum).to eq(106_826)
      end
    end

    context "when wallet currency does not match invoice currency" do
      let(:wallets) { [eur_wallet, usd_wallet] }
      let(:eur_wallet) do
        create(:wallet, :with_inbound_transaction, name: "eur wallet", customer:, balance_cents: 1000, currency: "EUR")
      end
      let(:usd_wallet) do
        create(:wallet, :with_inbound_transaction, name: "usd wallet", customer:, balance_cents: 1000, currency: "USD")
      end

      it "only includes wallets matching the invoice currency" do
        expect(result).to be_success
        expect(result.wallet_transactions).to eq({eur_wallet => 100})
      end
    end

    context "when no wallets match the invoice currency" do
      let(:wallets) do
        [create(:wallet, name: "usd wallet", customer:, balance_cents: 1000, currency: "USD")]
      end

      it "returns success with an empty hash" do
        expect(result).to be_success
        expect(result.wallet_transactions).to eq({})
      end
    end
  end
end
