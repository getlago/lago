# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceSettlement do
  subject(:invoice_settlement) { build(:invoice_settlement) }

  describe "enums" do
    it do
      expect(subject)
        .to define_enum_for(:settlement_type)
        .backed_by_column_of_type(:enum)
        .with_values(payment: "payment", credit_note: "credit_note")
    end
  end

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:billing_entity)
      expect(subject).to belong_to(:target_invoice).class_name("Invoice")
      expect(subject).to belong_to(:source_payment).class_name("Payment").optional
      expect(subject).to belong_to(:source_credit_note).class_name("CreditNote").optional
    end
  end

  describe "validations" do
    it do
      expect(subject).to validate_numericality_of(:amount_cents).is_greater_than(0)
      expect(subject).to validate_inclusion_of(:amount_currency).in_array(described_class.currency_list)
      expect(subject).to validate_presence_of(:settlement_type)
    end

    describe "source presence validation" do
      context "when settlement_type is payment" do
        subject(:invoice_settlement) { build(:invoice_settlement, settlement_type: :payment) }

        it "requires source_payment_id" do
          invoice_settlement.source_payment_id = nil
          expect(invoice_settlement).not_to be_valid
          expect(invoice_settlement.errors[:source_payment_id]).to include("must be present when settlement type is payment")
        end

        it "does not allow source_credit_note_id" do
          invoice_settlement.source_credit_note_id = create(:credit_note).id
          expect(invoice_settlement).not_to be_valid
          expect(invoice_settlement.errors[:source_credit_note_id]).to include("must be blank when settlement type is payment")
        end
      end

      context "when settlement_type is credit_note" do
        subject(:invoice_settlement) { build(:invoice_settlement, settlement_type: :credit_note) }

        it "requires source_credit_note_id" do
          invoice_settlement.source_credit_note_id = nil
          expect(invoice_settlement).not_to be_valid
          expect(invoice_settlement.errors[:source_credit_note_id]).to include("must be present when settlement type is credit_note")
        end

        it "does not allow source_payment_id" do
          invoice_settlement.source_payment_id = create(:payment).id
          expect(invoice_settlement).not_to be_valid
          expect(invoice_settlement.errors[:source_payment_id]).to include("must be blank when settlement type is credit_note")
        end
      end
    end
  end
end
