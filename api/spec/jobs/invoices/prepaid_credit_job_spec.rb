# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::PrepaidCreditJob do
  let(:invoice) { create(:invoice, customer:, organization: customer.organization) }
  let(:customer) { create(:customer) }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) { create(:wallet, customer:, balance_cents: 1000, credits_balance: 10.0) }
  let(:wallet_transaction) do
    create(:wallet_transaction, wallet:, amount: 15.0, credit_amount: 15.0, status: "pending")
  end
  let(:fee) do
    create(
      :fee,
      fee_type: "credit",
      invoiceable_type: "WalletTransaction",
      invoiceable_id: wallet_transaction.id,
      invoice:
    )
  end

  before do
    wallet_transaction
    fee
    subscription
    invoice.update(invoice_type: "credit")
  end

  it "updates wallet balance" do
    described_class.perform_now(invoice)

    expect(wallet.reload.balance_cents).to eq(2500)
  end

  it "settles the wallet transaction" do
    described_class.perform_now(invoice)

    expect(wallet_transaction.reload.status).to eq("settled")
  end

  it "finalize the invoice" do
    allow(Invoices::FinalizeOpenCreditService).to receive(:call)
    described_class.perform_now(invoice)
    expect(Invoices::FinalizeOpenCreditService).to have_received(:call).with(invoice:)
  end

  it "does not retry the job" do
    expect {
      described_class.perform_now(invoice)
    }.not_to have_enqueued_job(described_class)
  end

  context "when there is race condition error" do
    before do
      allow(Wallets::ApplyPaidCreditsService).to receive(:call).and_raise(ActiveRecord::StaleObjectError.new)
    end

    it "retries the job" do
      expect {
        described_class.perform_now(invoice)
      }.to have_enqueued_job(described_class)
    end
  end

  shared_examples "does not grant credits" do |payment_status|
    it "marks the wallet transaction as failed" do
      allow(WalletTransactions::MarkAsFailedService).to receive(:new).and_call_original
      described_class.perform_now(invoice, payment_status)
      expect(WalletTransactions::MarkAsFailedService).to have_received(:new).with(wallet_transaction: wallet_transaction)
      expect(wallet_transaction.reload.status).to eq("failed")
    end

    it "does not grant prepaid credits" do
      expect {
        described_class.perform_now(invoice, payment_status)
      }.not_to change { wallet.reload.balance_cents }
    end

    it "does not call the invoice FinalizeOpenCreditService" do
      allow(Invoices::FinalizeOpenCreditService).to receive(:call)
      described_class.perform_now(invoice, payment_status)
      expect(Invoices::FinalizeOpenCreditService).not_to have_received(:call)
    end
  end

  context "when payment fails" do
    it_behaves_like "does not grant credits", :failed
  end

  context "when invoice is paid by credit note" do
    let(:source_credit_note) { create(:credit_note, invoice:, customer:) }

    before do
      create(:invoice_settlement, target_invoice: invoice, source_credit_note:, settlement_type: :credit_note)
    end

    it_behaves_like "does not grant credits", :succeeded
  end

  context "when payment_status is not provided (Default to :succeeded for old jobs)" do
    it "defaults to :succeeded and grants prepaid credits" do
      described_class.perform_now(invoice)

      expect(wallet.reload.balance_cents).to eq(2500)
      expect(wallet_transaction.reload.status).to eq("settled")
    end
  end

  describe "#lock_key_arguments" do
    it "returns invoice and payment_status" do
      job = described_class.new(invoice, :succeeded)
      expect(job.lock_key_arguments).to eq([invoice, :succeeded])
    end

    it "defaults payment_status to :succeeded when not provided" do
      job = described_class.new(invoice)
      expect(job.lock_key_arguments).to eq([invoice, :succeeded])
    end

    it "converts payment_status string to symbol" do
      job = described_class.new(invoice, "failed")
      expect(job.lock_key_arguments).to eq([invoice, :failed])
    end
  end
end
