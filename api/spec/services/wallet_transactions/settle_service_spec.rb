# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactions::SettleService do
  subject(:service) { described_class.new(wallet_transaction:) }

  let(:wallet_transaction) { create(:wallet_transaction, status: "pending", settled_at: nil) }

  describe ".call" do
    it "updates wallet_transaction status" do
      expect {
        service.call
      }.to change { wallet_transaction.reload.status }.from("pending").to("settled")
        .and change(wallet_transaction, :settled_at).from(nil)
    end

    it "enqueues a SendWebhookJob for each wallet transaction" do
      expect do
        service.call
      end.to have_enqueued_job(SendWebhookJob).with("wallet_transaction.updated", WalletTransaction)
    end

    it "produces an activity log" do
      described_class.call(wallet_transaction:)

      expect(Utils::ActivityLog).to have_produced("wallet_transaction.updated").after_commit.with(wallet_transaction)
    end

    context "with inbound transaction on traceable wallet" do
      let(:customer) { create(:customer) }
      let(:wallet) { create(:wallet, customer:, traceable: true) }
      let(:wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          status: "pending",
          transaction_type: :inbound,
          settled_at: nil,
          remaining_amount_cents: nil)
      end

      it "sets remaining_amount_cents to amount_cents" do
        service.call

        expect(wallet_transaction.reload.remaining_amount_cents).to eq(wallet_transaction.amount_cents)
      end
    end

    context "with outbound transaction" do
      let(:wallet_transaction) do
        create(:wallet_transaction,
          status: "pending",
          transaction_type: :outbound,
          settled_at: nil,
          remaining_amount_cents: nil)
      end

      it "does not set remaining_amount_cents" do
        service.call

        expect(wallet_transaction.reload.remaining_amount_cents).to be_nil
      end
    end

    context "with inbound transaction on non-traceable wallet" do
      let(:customer) { create(:customer) }
      let(:wallet) { create(:wallet, customer:, traceable: false) }
      let(:wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          status: "pending",
          transaction_type: :inbound,
          settled_at: nil,
          remaining_amount_cents: nil)
      end

      it "does not set remaining_amount_cents" do
        service.call

        expect(wallet_transaction.reload.remaining_amount_cents).to be_nil
      end
    end
  end
end
