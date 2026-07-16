# frozen_string_literal: true

require "rails_helper"

RSpec.describe Wallets::Balance::UpdateOngoingService do
  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, awaiting_wallet_refresh: true) }

  let(:wallet) do
    create(
      :wallet,
      customer:,
      balance_cents: 1000,
      ongoing_balance_cents: 800,
      ongoing_usage_balance_cents: 200,
      credits_balance: 10.0,
      credits_ongoing_balance: 8.0,
      credits_ongoing_usage_balance: 2.0
    )
  end

  let(:update_params) do
    {
      ongoing_usage_balance_cents: 550,
      credits_ongoing_usage_balance: 5.5,
      ongoing_balance_cents: 450,
      credits_ongoing_balance: 4.5,
      depleted_ongoing_balance:
    }
  end

  before do
    wallet
    allow(Wallets::ThresholdTopUpService).to receive(:call).and_call_original
  end

  describe "#call" do
    subject(:result) { described_class.call(wallet:, update_params:) }

    context "when ongoing balance is not depleted" do
      let(:depleted_ongoing_balance) { false }

      it "updates wallet balance" do
        freeze_time do
          expect { subject }
            .to change(wallet.reload, :ongoing_usage_balance_cents).from(200).to(550)
            .and change(wallet, :credits_ongoing_usage_balance).from(2.0).to(5.5)
            .and change(wallet, :ongoing_balance_cents).from(800).to(450)
            .and change(wallet, :credits_ongoing_balance).from(8.0).to(4.5)
            .and change(wallet, :last_ongoing_balance_sync_at).from(nil).to(Time.current)
            .and not_change(wallet, :last_balance_sync_at)

          expect(wallet.depleted_ongoing_balance).to eq false
        end
      end

      it "does not send depleted_ongoing_balance webhook" do
        expect { subject }.not_to have_enqueued_job(SendWebhookJob)
      end

      it "calls Wallets::ThresholdTopUpService" do
        subject
        expect(Wallets::ThresholdTopUpService).to have_received(:call).with(wallet:)
      end

      it "enqueues a ProcessWalletAlertsJob" do
        expect { subject }.to have_enqueued_job(UsageMonitoring::ProcessWalletAlertsJob).at_least(:once)
      end
    end

    context "when ongoing balance is depleted" do
      let(:depleted_ongoing_balance) { true }

      it "updates wallet balance" do
        freeze_time do
          expect { subject }
            .to change(wallet.reload, :ongoing_usage_balance_cents).from(200).to(550)
            .and change(wallet, :credits_ongoing_usage_balance).from(2.0).to(5.5)
            .and change(wallet, :ongoing_balance_cents).from(800).to(450)
            .and change(wallet, :credits_ongoing_balance).from(8.0).to(4.5)
            .and change(wallet, :last_ongoing_balance_sync_at).from(nil).to(Time.current)
            .and not_change(wallet, :last_balance_sync_at)

          expect(wallet.depleted_ongoing_balance).to eq true
        end
      end

      it "sends depleted_ongoing_balance webhook" do
        expect { subject }
          .to have_enqueued_job(SendWebhookJob)
          .with("wallet.depleted_ongoing_balance", Wallet)
      end

      it "calls Wallets::ThresholdTopUpService" do
        subject
        expect(Wallets::ThresholdTopUpService).to have_received(:call).with(wallet:)
      end
    end

    context "when skip_single_wallet_update is true" do
      subject(:result) { described_class.call(wallet:, update_params:, skip_single_wallet_update: true) }

      let(:depleted_ongoing_balance) { false }

      it "updates wallet balance but does not update last_ongoing_balance_sync_at" do
        expect { subject }
          .to change(wallet.reload, :ongoing_usage_balance_cents).from(200).to(550)
          .and change(wallet, :credits_ongoing_usage_balance).from(2.0).to(5.5)
          .and change(wallet, :ongoing_balance_cents).from(800).to(450)
          .and change(wallet, :credits_ongoing_balance).from(8.0).to(4.5)
          .and not_change(wallet, :last_ongoing_balance_sync_at)
      end
    end
  end
end
