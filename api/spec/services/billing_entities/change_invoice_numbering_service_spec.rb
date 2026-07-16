# frozen_string_literal: true

require "rails_helper"

RSpec.describe BillingEntities::ChangeInvoiceNumberingService do
  subject(:result) { described_class.call(billing_entity:, document_numbering:) }

  let(:billing_entity) { create(:billing_entity, document_numbering: "per_customer") }
  let(:organization) { billing_entity.organization }
  let(:document_numbering) { "per_billing_entity" }

  describe "#call" do
    it "updates the billing_entity's document_numbering" do
      expect(result).to be_success
      expect(result.billing_entity).to be_per_billing_entity
    end

    context "when document_numbering is not changing" do
      let(:document_numbering) { "per_customer" }

      it "returns early without making changes" do
        expect(result).to be_success
        expect(result.billing_entity).to be_per_customer
      end
    end

    context "when changing from per_customer to per_billing_entity" do
      let(:customer) { create(:customer, billing_entity:) }
      let(:invoice1) { create(:invoice, customer:, organization:, billing_entity:, status: "finalized", self_billed: false) }
      let(:invoice2) { create(:invoice, customer:, organization:, billing_entity:, status: "finalized", self_billed: false) }
      let(:invoice3) { create(:invoice, customer:, organization:, billing_entity:, status: "draft", self_billed: false) }
      let(:voided_invoice) { create(:invoice, customer:, organization:, billing_entity:, status: "voided", self_billed: false) }
      let(:self_billed_invoice) { create(:invoice, customer:, organization:, billing_entity:, status: "finalized", self_billed: true) }

      before do
        invoice1
        invoice2
        invoice3
        self_billed_invoice
        voided_invoice
      end

      it "updates the billing_entity sequential id for the latest invoice" do
        expect {
          result
        }.to change { voided_invoice.reload.billing_entity_sequential_id }.to(3)

        expect(billing_entity).to be_per_billing_entity
      end

      it "only counts non-self-billed invoices with generated numbers" do
        expect(result).to be_success
        expect(voided_invoice.reload.billing_entity_sequential_id).to eq(3)
      end

      context "when last created invoice already has a billing_entity_sequential_id" do
        let(:voided_invoice) do
          create(:invoice, customer:, organization:, billing_entity:, status: "voided", self_billed: false, billing_entity_sequential_id: 1, created_at: 1.day.from_now)
        end

        it "changes the billing_entity_sequential_id on the latest invoice without it" do
          expect(result).to be_success
          expect(invoice2.reload.billing_entity_sequential_id).to eq(3)
        end
      end
    end

    context "when changing from per_billing_entity to per_customer" do
      let(:billing_entity) { create(:billing_entity, document_numbering: "per_billing_entity") }
      let(:document_numbering) { "per_customer" }

      it "updates the billing_entity's document_numbering without other changes" do
        expect(result).to be_success
        expect(result.billing_entity).to be_per_customer
      end
    end
  end
end
