# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransactions::RecreditService do
  subject(:service) { described_class.new(wallet_transaction:) }

  let(:wallet_transaction) { create(:wallet_transaction, wallet:) }

  context "when wallet is terminated" do
    let(:wallet) { create(:wallet, :terminated) }

    it "returns a failure" do
      result = service.call

      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
      expect(result.error.message).to eq("wallet_not_active")
    end
  end

  context "when wallet is active" do
    let(:wallet) { create(:wallet, consumed_credits: 1.0) }

    it "recredits the wallet" do
      expect { service.call }.to change { wallet.reload.credits_balance }.from(0).to(1.0)

      expect(service.call).to be_success
    end

    it "resets consumed credits of the wallet" do
      expect { service.call }.to change { wallet.reload.consumed_credits }.from(1.0).to(0)

      expect(service.call).to be_success
    end

    context "when the credits to restore round to zero monetary value" do
      let(:wallet) { create(:wallet, rate_amount: "0.01") }
      let(:wallet_transaction) do
        create(:wallet_transaction, wallet:, transaction_type: :outbound, credit_amount: 0.4)
      end

      it "skips the recredit without creating a transaction" do
        expect { service.call }.not_to change(WalletTransaction.inbound, :count)
        expect(service.call).to be_success
      end
    end

    context "when wallet transaction has an invoice" do
      let(:voided_invoice) { create(:invoice, :voided, organization: wallet.organization) }
      let(:wallet_transaction) do
        create(:wallet_transaction,
          wallet:,
          invoice: voided_invoice,
          transaction_type: :outbound,
          credit_amount: 5.0)
      end

      it "creates an inbound transaction linked to the voided invoice with correct attributes" do
        expect { service.call }.to change(WalletTransaction.inbound, :count).by(1)

        new_transaction = WalletTransaction.inbound.last
        expect(new_transaction).to have_attributes(
          voided_invoice_id: voided_invoice.id,
          transaction_type: "inbound",
          transaction_status: "granted",
          credit_amount: wallet_transaction.credit_amount
        )
      end
    end
  end
end
