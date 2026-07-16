# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::Balance::IncreaseService do
  subject(:create_service) { described_class.new(wallet:, wallet_transaction:) }

  let(:credits_amount) { BigDecimal("4.5") }
  let(:wallet) do
    create(
      :wallet,
      balance_cents: 1000,
      credits_balance: 10.0,
      ongoing_balance_cents: 800,
      credits_ongoing_balance: 8.0,
      consumed_credits: 1.0,
      consumed_amount_cents: 100
    )
  end

  let(:wallet_credit) { WalletCredit.new(wallet:, credit_amount: credits_amount) }
  let(:credit_amount) { wallet_credit.credit_amount }
  let(:amount) { wallet_credit.amount }
  let(:wallet_transaction) { create(:wallet_transaction, wallet:, credit_amount:, amount:) }

  before { wallet }

  def call_and_reload_wallet
    create_service.call
    wallet.reload
  end

  describe ".call" do
    it "updates wallet balance" do
      call_and_reload_wallet

      expect(wallet.balance_cents).to eq(1450)
      expect(wallet.credits_balance).to eq(14.5)
    end

    it "enqueues a RefreshWalletJob targeting the wallet" do
      expect { create_service.call }
        .to have_enqueued_job_after_commit(Customers::RefreshWalletJob).with(wallet.customer, wallet_ids: [wallet.id])
    end

    it "sends a `wallet.updated` webhook" do
      expect { create_service.call }
        .to have_enqueued_job(SendWebhookJob).with("wallet.updated", Wallet)
    end

    it "enqueues a ProcessWalletAlertsJob" do
      expect { create_service.call }
        .to have_enqueued_job(UsageMonitoring::ProcessWalletAlertsJob).at_least(:once)
    end

    context "with rounding" do
      let(:wallet_credit) { WalletCredit.new(wallet:, credit_amount: credits_amount, invoiceable: false) }
      let(:credits_amount) { BigDecimal("17.96999") }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:, credit_amount: wallet_credit.credit_amount, amount: wallet_credit.amount) }

      it "updates wallet balance" do
        expect(wallet_credit.amount).to eq(17.97)

        call_and_reload_wallet

        expect(wallet.balance.to_d).to eq(27.97)
        expect(wallet.credits_balance).to eq(0.2796999e2)
      end
    end

    context "when reset_consumed_credits is true" do
      subject(:create_service) { described_class.new(wallet:, wallet_transaction:, reset_consumed_credits: true) }

      let!(:wallet_transaction) { create(:wallet_transaction, wallet:, amount: 0.5, credit_amount: 0.5) }

      it "resets consumed credits" do
        call_and_reload_wallet
        expect(wallet.consumed_credits).to eq(0.5)
        expect(wallet.consumed_amount_cents).to eq(50)
      end

      context "when the consumed credits are greater than the credits amount" do
        let(:wallet_transaction) { create(:wallet_transaction, wallet:, amount: 2.0, credit_amount: 2.0) }

        it "resets consumed credits" do
          call_and_reload_wallet

          expect(wallet.consumed_credits).to eq(0)
          expect(wallet.consumed_amount_cents).to eq(0)
        end
      end
    end
  end
end
