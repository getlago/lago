# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceSettlements::CreateService do
  subject(:service_call) do
    described_class.call(
      invoice:,
      amount_cents:,
      amount_currency:,
      source_credit_note:,
      source_payment:
    )
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      currency: "EUR",
      total_amount_cents: 1000,
      total_paid_amount_cents: 0
    )
  end
  let(:amount_cents) { 500 }
  let(:amount_currency) { "EUR" }
  let(:source_credit_note) { nil }
  let(:source_payment) { nil }

  describe ".call" do
    context "with source_credit_note" do
      let(:credit_note) do
        create(:credit_note, invoice:, customer:, offset_amount_cents: 500,
          total_amount_cents: 500, status: :finalized)
      end
      let(:source_credit_note) { credit_note }

      it "creates settlement with correct attributes and does not mark partial as paid" do
        expect { service_call }.to change(InvoiceSettlement, :count).by(1)

        result = service_call
        expect(result).to be_success
        settlement = result.invoice_settlement

        expect(settlement.organization_id).to eq(organization.id)
        expect(settlement.billing_entity_id).to eq(invoice.billing_entity_id)
        expect(settlement.target_invoice).to eq(invoice)
        expect(settlement.source_credit_note).to eq(credit_note)
        expect(settlement.source_payment).to be_nil
        expect(settlement.settlement_type).to eq("credit_note")
        expect(settlement.amount_cents).to eq(500)
        expect(settlement.amount_currency).to eq("EUR")
        expect(invoice.reload.payment_status).not_to eq("succeeded")
      end

      it "marks invoice as paid when fully settled by single offset" do
        cn = create(:credit_note, invoice:, customer:, offset_amount_cents: 1000,
          total_amount_cents: 1000, status: :finalized)
        described_class.call(invoice:, amount_cents: 1000, amount_currency: "EUR", source_credit_note: cn)

        expect(invoice.reload.payment_status).to eq("succeeded")
      end

      it "marks invoice as paid when offset completes partial payment" do
        invoice.update!(total_paid_amount_cents: 600)
        cn = create(:credit_note, invoice:, customer:, offset_amount_cents: 400,
          total_amount_cents: 400, status: :finalized)
        described_class.call(invoice:, amount_cents: 400, amount_currency: "EUR", source_credit_note: cn)

        expect(invoice.reload.payment_status).to eq("succeeded")
      end

      it "marks invoice as paid when multiple settlements complete payment" do
        cn1 = create(:credit_note, invoice:, customer:, offset_amount_cents: 600,
          total_amount_cents: 600, status: :finalized)
        cn2 = create(:credit_note, invoice:, customer:, offset_amount_cents: 400,
          total_amount_cents: 400, status: :finalized)

        described_class.call(invoice:, amount_cents: 600, amount_currency: "EUR", source_credit_note: cn1)
        described_class.call(invoice:, amount_cents: 400, amount_currency: "EUR", source_credit_note: cn2)

        expect(invoice.reload.payment_status).to eq("succeeded")
      end

      it "marks invoice as paid when offset exactly matches total" do
        invoice.update!(total_amount_cents: 500)
        cn = create(:credit_note, invoice:, customer:, offset_amount_cents: 500,
          total_amount_cents: 500, status: :finalized)
        described_class.call(invoice:, amount_cents: 500, amount_currency: "EUR", source_credit_note: cn)

        expect(invoice.reload.payment_status).to eq("succeeded")
      end

      it "marks invoice as paid when offset slightly exceeds due amount" do
        invoice.update!(total_amount_cents: 1000, total_paid_amount_cents: 999)
        cn = create(:credit_note, invoice:, customer:, offset_amount_cents: 2,
          total_amount_cents: 2, status: :finalized)
        described_class.call(invoice:, amount_cents: 2, amount_currency: "EUR", source_credit_note: cn)

        expect(invoice.reload.payment_status).to eq("succeeded")
      end

      it "creates settlement with specified currency" do
        cn = create(:credit_note, invoice:, customer:, offset_amount_cents: 500,
          offset_amount_currency: "USD", total_amount_cents: 500, status: :finalized)
        result = described_class.call(invoice:, amount_cents: 500, amount_currency: "USD", source_credit_note: cn)

        expect(result.invoice_settlement.amount_currency).to eq("USD")
      end
    end

    context "with source_payment" do
      let(:payment) { create(:payment, payable: invoice) }
      let(:source_payment) { payment }

      it "creates settlement with correct attributes" do
        expect { service_call }.to change(InvoiceSettlement, :count).by(1)

        result = service_call
        expect(result).to be_success
        settlement = result.invoice_settlement

        expect(settlement.organization_id).to eq(organization.id)
        expect(settlement.target_invoice).to eq(invoice)
        expect(settlement.source_payment).to eq(payment)
        expect(settlement.source_credit_note).to be_nil
        expect(settlement.settlement_type).to eq("payment")
        expect(settlement.amount_cents).to eq(500)
        expect(settlement.amount_currency).to eq("EUR")
      end
    end

    context "with invalid sources" do
      it "raises error when no source provided" do
        expect { service_call }.to raise_error(ArgumentError, "Must provide either source_credit_note or source_payment")
      end

      it "raises error when both sources provided" do
        service = described_class.new(
          invoice:, amount_cents: 500, amount_currency: "EUR",
          source_credit_note: create(:credit_note, invoice:, customer:),
          source_payment: create(:payment, payable: invoice)
        )
        expect { service.call }.to raise_error(ArgumentError, "Cannot provide both source_credit_note and source_payment")
      end
    end
  end
end
