# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::BuildRegenerationPreviewService do
  subject(:preview_service) { described_class.new(invoice:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:, plan:) }
  let(:invoice) { create(:invoice, organization:, customer:, taxes_rate: 10) }
  let(:invoice_subscription) { create(:invoice_subscription, invoice:, subscription:) }

  describe "#call" do
    let(:fee) do
      create(
        :fee,
        invoice:,
        subscription:,
        fee_type: "subscription",
        units: 1,
        amount_cents: 1000,
        taxes_rate: 10,
        amount_currency: "EUR",
        invoice_display_name: "Subscription Fee"
      )
    end

    before do
      allow(Fees::ApplyTaxesService).to receive(:call!).and_call_original
      allow(Invoices::ComputeAmountsFromFees).to receive(:call).and_call_original

      invoice_subscription
      fee
    end

    it "builds a preview invoice with fees" do
      result = preview_service.call

      expect(result).to be_success
      expect(result.invoice.id).to eq(invoice.id)
      expect(result.invoice.fees.size).to eq(1)
      expect(result.invoice.taxes_rate).to eq(0)
    end

    it "calls ApplyTaxesService for fee" do
      preview_service.call

      expect(Fees::ApplyTaxesService).to have_received(:call!).at_least(:once).with(fee:)
    end

    it "does not apply provider taxes" do
      preview_service.call

      expect(Invoices::ComputeAmountsFromFees).to have_received(:call).with(
        invoice: be_a(Invoice),
        provider_taxes: nil
      )
    end

    context "when the customer has a tax customer" do
      let(:integration) { create(:anrok_integration, organization:) }

      before do
        create(:anrok_customer, integration:, customer:)
        allow(Invoices::ApplyProviderTaxesService).to receive(:call!)
      end

      it "does not apply provider taxes" do
        preview_service.call

        expect(Invoices::ApplyProviderTaxesService).not_to have_received(:call!)
      end
    end

    context "with multiple fees" do
      let(:charge) { create(:standard_charge, plan:) }
      let(:charge_fee) do
        create(
          :charge_fee,
          invoice:,
          subscription:,
          charge:,
          fee_type: "charge",
          units: 3,
          amount_cents: 300,
          taxes_rate: 10,
          amount_currency: "EUR"
        )
      end

      before { charge_fee }

      it "builds a preview invoice with all fees" do
        result = preview_service.call

        expect(result).to be_success
        expect(result.invoice.fees.size).to eq(2)
      end

      it "calls ApplyTaxesService for each fee" do
        preview_service.call

        expect(Fees::ApplyTaxesService).to have_received(:call!).at_least(:once).with(fee:)
        expect(Fees::ApplyTaxesService).to have_received(:call!).at_least(:once).with(fee: charge_fee)
      end
    end

    context "with taxes" do
      let(:tax) { create(:tax, organization:, rate: 12, applied_to_organization: false) }
      let(:applied_tax) { create(:plan_applied_tax, plan:, tax:) }

      before { applied_tax }

      it "applies taxes and assigns ids to applied taxes" do
        result = preview_service.call
        preview_applied_tax = result.invoice.applied_taxes.first

        expect(preview_applied_tax).not_to be_nil
        expect(preview_applied_tax.id).to be_present
        expect(preview_applied_tax.invoice_id).to eq(invoice.id)
        expect(preview_applied_tax.tax_rate).to eq(12)
        expect(result.invoice.taxes_rate).to eq(12)
      end

      it "assigns ids and original fee ids to fee applied taxes" do
        result = preview_service.call
        preview_fee = result.invoice.fees.find { |result_fee| result_fee.id == fee.id }
        preview_fee_applied_tax = preview_fee.applied_taxes.first

        expect(preview_fee_applied_tax).not_to be_nil
        expect(preview_fee_applied_tax.id).to be_present
        expect(preview_fee_applied_tax.fee_id).to eq(fee.id)
        expect(preview_fee_applied_tax.tax_rate).to eq(12)
      end
    end
  end
end
