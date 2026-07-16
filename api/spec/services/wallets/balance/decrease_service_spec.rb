# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::Balance::DecreaseService do
  let(:wallet) do
    create(
      :wallet,
      balance_cents: 1000,
      ongoing_balance_cents: 800,
      credits_balance: 10.0,
      credits_ongoing_balance: 8.0
    )
  end

  let(:wallet_transaction) do
    create(:wallet_transaction, wallet:, amount: "4.5", credit_amount: BigDecimal("4.5"))
  end

  before do
    wallet
    wallet_transaction
  end

  describe ".call" do
    subject(:result) { described_class.call!(wallet:, wallet_transaction:, skip_refresh:) }

    let(:skip_refresh) { false }

    it "updates wallet balance" do
      expect { subject }
        .to change(wallet.reload, :balance_cents).from(1000).to(550)
        .and change(wallet, :credits_balance).from(10.0).to(5.5)
    end

    it "updates wallet consumed status" do
      expect { subject }
        .to change(wallet.reload, :consumed_credits).from(0).to(4.5)
        .and change(wallet, :consumed_amount_cents).from(0).to(450)
    end

    it "flags the customer wallets for refresh" do
      expect { subject }.to change { wallet.customer.reload.awaiting_wallet_refresh }.from(false).to(true)
    end

    it "enqueues a RefreshWalletJob" do
      expect { subject }
        .to have_enqueued_job_after_commit(Customers::RefreshWalletJob).with(wallet.customer)
    end

    it "sends a `wallet.updated` webhook" do
      expect { subject }.to have_enqueued_job(SendWebhookJob).with("wallet.updated", Wallet)
    end

    it "enqueues a ProcessWalletAlertsJob" do
      expect { subject }.to have_enqueued_job(UsageMonitoring::ProcessWalletAlertsJob).at_least(:once)
    end

    context "when skip refresh flag is set" do
      let(:skip_refresh) { true }

      it "does not flag the customer wallets for refresh" do
        expect { subject }.not_to change { wallet.customer.reload.awaiting_wallet_refresh }.from(false)
      end

      it "does not enqueue a RefreshWalletJob" do
        expect { subject }.not_to have_enqueued_job(Customers::RefreshWalletJob)
      end
    end

    context "when wallet is stale" do
      it "retries the update on stale object" do
        # Create a stale version by loading the same wallet twice
        stale_wallet = Wallet.find(wallet.id)
        current_wallet = Wallet.find(wallet.id)

        # Update the current wallet to make stale_wallet outdated
        current_wallet.update!(credits_balance: 15.0)

        # Create service with stale wallet
        service = described_class.new(wallet: stale_wallet, wallet_transaction:)

        # Should succeed despite the stale wallet
        expect { service.call }
          .to change { stale_wallet.reload.credits_balance }.from(15.0).to(10.5)
          .and change { stale_wallet.consumed_credits }.from(0).to(4.5)
      end
    end

    context "when the rate can produce rounding issues" do
      let(:wallet) do
        create(
          :wallet,
          balance_cents: 13750,
          credits_balance: 100.0,
          rate_amount: BigDecimal("1.375")
        )
      end

      let(:wallet_transaction) do
        create(:wallet_transaction, wallet:, amount: "1.00", credit_amount: BigDecimal("0.72727"))
      end

      it "correctly updates wallet balance and consumed status" do
        expect { subject }
          .to change(wallet.reload, :consumed_credits).from(0).to(0.72727)
          .and change(wallet, :consumed_amount_cents).from(0).to(100)
          .and change(wallet, :balance_cents).from(13750).to(13650)
          .and change(wallet, :credits_balance).from(100.0).to(99.27273)
      end
    end
  end
end
