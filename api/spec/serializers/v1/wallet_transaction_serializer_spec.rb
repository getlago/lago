# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::WalletTransactionSerializer do
  subject(:serializer) do
    described_class.new(wallet_transaction, root_name: "wallet_transaction", includes:)
  end

  let(:wallet_transaction) { create(:wallet_transaction) }
  let(:includes) { [] }

  context "when includes is empty" do
    it "serializes the object" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction"]).to include(
        "lago_id" => wallet_transaction.id,
        "lago_wallet_id" => wallet_transaction.wallet_id,
        "lago_invoice_id" => nil,
        "lago_credit_note_id" => nil,
        "lago_voided_invoice_id" => nil,
        "billing_entity_code" => wallet_transaction.billing_entity.code,
        "status" => wallet_transaction.status,
        "source" => wallet_transaction.source,
        "transaction_status" => wallet_transaction.transaction_status,
        "transaction_type" => wallet_transaction.transaction_type,
        "amount" => wallet_transaction.amount.to_s,
        "credit_amount" => wallet_transaction.credit_amount.to_s,
        "remaining_amount_cents" => wallet_transaction.remaining_amount_cents,
        "remaining_credit_amount" => wallet_transaction.remaining_credit_amount,
        "priority" => wallet_transaction.priority,
        "settled_at" => wallet_transaction.settled_at&.iso8601,
        "failed_at" => wallet_transaction.failed_at&.iso8601,
        "created_at" => wallet_transaction.created_at.iso8601,
        "invoice_requires_successful_payment" => wallet_transaction.invoice_requires_successful_payment?,
        "metadata" => wallet_transaction.metadata,
        "name" => "Custom Transaction Name"
      )
      expect(result["wallet_transaction"]["payment_method"]["payment_method_id"]).to eq(nil)
      expect(result["wallet_transaction"]["payment_method"]["payment_method_type"]).to eq("provider")
    end
  end

  context "when transaction has no snapshotted billing entity" do
    let(:wallet_transaction) { create(:wallet_transaction, billing_entity: nil) }

    it "serializes the wallet's billing entity code" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction"]["billing_entity_code"]).to eq(wallet_transaction.wallet.billing_entity.code)
    end
  end

  context "when snapshotted billing entity differs from the wallet's current one" do
    let(:wallet) { create(:wallet) }
    let(:snapshot_billing_entity) { create(:billing_entity, organization: wallet.organization) }
    let(:wallet_transaction) { create(:wallet_transaction, wallet:, billing_entity: snapshot_billing_entity) }

    it "serializes the snapshotted billing entity code" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction"]["billing_entity_code"]).to eq(snapshot_billing_entity.code)
    end
  end

  context "when transaction has an invoice and a credit note" do
    let(:wallet_transaction) { create(:wallet_transaction, :with_invoice, :with_credit_note) }

    it "serializes the invoice id" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction"]).to include(
        "lago_invoice_id" => wallet_transaction.invoice.id,
        "lago_credit_note_id" => wallet_transaction.credit_note.id
      )
    end
  end

  context "when transaction has a voided_invoice" do
    let(:voided_invoice) { create(:invoice) }
    let(:wallet_transaction) { create(:wallet_transaction, voided_invoice:) }

    it "serializes the voided_invoice_id" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction"]).to include(
        "lago_voided_invoice_id" => voided_invoice.id
      )
    end
  end

  context "when includes wallet is set" do
    let(:includes) { %i[wallet] }
    let(:wallet) { wallet_transaction.wallet }

    it "includes the wallet" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction"]["wallet"]).to include(
        "lago_id" => wallet.id,
        "status" => wallet.status,
        "created_at" => wallet.created_at.iso8601,
        "expiration_at" => wallet.expiration_at&.iso8601
      )
    end
  end

  context "when includes applied_invoice_custom_sections is set" do
    let(:includes) { %i[applied_invoice_custom_sections] }
    let(:invoice_custom_section) { create(:wallet_transaction_applied_invoice_custom_section, wallet_transaction:) }

    before { invoice_custom_section }

    it "includes the invoice_custom_sections" do
      result = JSON.parse(serializer.to_json)

      expect(result["wallet_transaction"]["applied_invoice_custom_sections"].first).to include(
        "lago_id" => invoice_custom_section.id
      )
    end
  end
end
