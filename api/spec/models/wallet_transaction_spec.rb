# frozen_string_literal: true

require "rails_helper"

RSpec.describe WalletTransaction do
  describe "validations" do
    it { is_expected.to validate_presence_of(:priority) }
    it { is_expected.to validate_inclusion_of(:priority).in_range(1..50) }
    it { is_expected.to validate_length_of(:name).is_at_most(255).is_at_least(1).allow_nil }
    it { is_expected.to validate_exclusion_of(:invoice_requires_successful_payment).in_array([nil]) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:transaction_type) }
    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_presence_of(:transaction_status) }

    describe "remaining_amount_cents validation" do
      it "allows remaining_amount_cents on inbound transactions" do
        transaction = build(:wallet_transaction, transaction_type: :inbound, remaining_amount_cents: 1000)
        expect(transaction).to be_valid
      end

      it "rejects negative remaining_amount_cents on inbound transactions" do
        transaction = build(:wallet_transaction, transaction_type: :inbound, remaining_amount_cents: -100)
        expect(transaction).not_to be_valid
        expect(transaction.errors.where(:remaining_amount_cents, :greater_than_or_equal_to)).to be_present
      end

      it "allows nil remaining_amount_cents on outbound transactions" do
        transaction = build(:wallet_transaction, transaction_type: :outbound, remaining_amount_cents: nil)
        expect(transaction).to be_valid
      end

      it "rejects remaining_amount_cents on outbound transactions" do
        transaction = build(:wallet_transaction, transaction_type: :outbound, remaining_amount_cents: 1000)
        expect(transaction).not_to be_valid
        expect(transaction.errors.where(:remaining_amount_cents, :present)).to be_present
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:wallet) }
    it { is_expected.to belong_to(:invoice).optional }
    it { is_expected.to belong_to(:credit_note).optional }
    it { is_expected.to belong_to(:voided_invoice).class_name("Invoice").optional }
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:billing_entity).optional }
    it { is_expected.to have_many(:consumptions).class_name("WalletTransactionConsumption").with_foreign_key(:inbound_wallet_transaction_id).inverse_of(:inbound_wallet_transaction).dependent(:destroy) }
    it { is_expected.to have_many(:fundings).class_name("WalletTransactionConsumption").with_foreign_key(:outbound_wallet_transaction_id).inverse_of(:outbound_wallet_transaction).dependent(:destroy) }
    it { is_expected.to have_many(:applied_invoice_custom_sections).class_name("WalletTransaction::AppliedInvoiceCustomSection").dependent(:destroy) }
    it { is_expected.to have_many(:selected_invoice_custom_sections).through(:applied_invoice_custom_sections).source(:invoice_custom_section) }
  end

  describe "enums" do
    it "defines expected enum values" do
      expect(described_class.defined_enums).to include(
        "status" => hash_including("pending", "settled", "failed"),
        "transaction_status" => hash_including("purchased", "granted", "voided", "invoiced"),
        "transaction_type" => hash_including("inbound", "outbound"),
        "source" => hash_including("manual", "interval", "threshold")
      )
    end
  end

  describe "Scopes" do
    describe ".available_inbound" do
      let(:wallet) { create(:wallet) }
      let(:inbound_settled_available) { create(:wallet_transaction, wallet:, transaction_type: :inbound, status: :settled, remaining_amount_cents: 1000) }
      let(:inbound_settled_exhausted) { create(:wallet_transaction, wallet:, transaction_type: :inbound, status: :settled, remaining_amount_cents: 0) }
      let(:inbound_pending) { create(:wallet_transaction, wallet:, transaction_type: :inbound, status: :pending, remaining_amount_cents: 1000) }
      let(:outbound_settled) { create(:wallet_transaction, wallet:, transaction_type: :outbound, status: :settled) }

      before do
        inbound_settled_available
        inbound_settled_exhausted
        inbound_pending
        outbound_settled
      end

      it "returns only inbound settled transactions with remaining balance" do
        expect(described_class.available_inbound).to eq([inbound_settled_available])
      end
    end

    describe ".in_consumption_order" do
      let(:wallet) { create(:wallet) }
      let!(:granted_priority_10) { create(:wallet_transaction, wallet:, transaction_status: :granted, priority: 10, created_at: 1.day.ago) }
      let!(:purchased_priority_5) { create(:wallet_transaction, wallet:, transaction_status: :purchased, priority: 5, created_at: 2.days.ago) }
      let!(:granted_priority_5) { create(:wallet_transaction, wallet:, transaction_status: :granted, priority: 5, created_at: 3.days.ago) }
      let!(:granted_priority_5_newer) { create(:wallet_transaction, wallet:, transaction_status: :granted, priority: 5, created_at: 1.day.ago) }

      it "orders by priority, then granted before purchased, then by created_at" do
        expect(described_class.in_consumption_order).to eq([
          granted_priority_5, # priority 5, granted, oldest
          granted_priority_5_newer, # priority 5, granted, newer
          purchased_priority_5, # priority 5, purchased
          granted_priority_10 # priority 10, granted
        ])
      end
    end
  end

  describe ".order_by_priority" do
    subject { described_class.order_by_priority }

    let(:wallet) { create(:wallet) }
    let!(:purchased_10) { create(:wallet_transaction, wallet:, priority: 10, transaction_status: :purchased, created_at: 3.days.ago) }
    let!(:granted_5) { create(:wallet_transaction, wallet:, priority: 5, transaction_status: :granted, created_at: 2.days.ago) }
    let!(:granted_10) { create(:wallet_transaction, wallet:, priority: 10, transaction_status: :granted, created_at: 1.day.ago) }
    let!(:voided_5) { create(:wallet_transaction, wallet:, priority: 5, transaction_status: :voided, created_at: 4.days.ago) }
    let!(:invoiced_15) { create(:wallet_transaction, wallet:, priority: 15, transaction_status: :invoiced, created_at: 5.days.ago) }
    let!(:granted_10_older) { create(:wallet_transaction, wallet:, priority: 10, transaction_status: :granted, created_at: 2.days.ago) }

    it "orders by priority first, then by transaction_status, then by created_at" do
      expect(subject.to_a).to eq([
        granted_5,
        voided_5,
        granted_10_older, # priority 10, granted, 2 days ago
        granted_10, # priority 10, granted, 1 day ago
        purchased_10,
        invoiced_15
      ])
    end
  end

  describe "#mark_as_failed!" do
    let(:transaction) { create(:wallet_transaction, status: :pending) }

    it "marks the transaction as failed" do
      expect { transaction.mark_as_failed! }
        .to change(transaction, :status).from("pending").to("failed")
        .and change(transaction, :failed_at).from(nil)
    end
  end

  describe "#remaining_credit_amount" do
    let(:wallet) { create(:wallet, rate_amount: "2.00", currency: "EUR") }

    context "when remaining_amount_cents is nil" do
      let(:transaction) { create(:wallet_transaction, wallet:, transaction_type: :inbound, remaining_amount_cents: nil) }

      it "returns nil" do
        expect(transaction.remaining_credit_amount).to be_nil
      end
    end

    context "when remaining_amount_cents is present" do
      let(:transaction) { create(:wallet_transaction, wallet:, transaction_type: :inbound, remaining_amount_cents: 5000) }

      it "converts cents to credit amount using the wallet rate" do
        # 5000 cents = 50.00 EUR, at rate 2.00 => 25.0 credits
        expect(transaction.remaining_credit_amount).to eq("25.0")
      end
    end
  end
end
