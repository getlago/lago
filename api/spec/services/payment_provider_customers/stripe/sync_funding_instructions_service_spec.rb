# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::Stripe::SyncFundingInstructionsService do
  subject(:sync_funding_service) { described_class.new(stripe_customer) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, currency: "USD") }
  let(:provider_customer_id) { "cus_Rw5Qso78STEap3" }
  let(:stripe_customer) {
    create(:stripe_customer, customer:, provider_payment_methods:,
      provider_customer_id:, payment_provider:)
  }
  let(:payment_provider) { create(:stripe_provider, organization:) }
  let(:provider_payment_methods) { %w[customer_balance] }

  describe "#call" do
    context "when customer is not eligible" do
      let(:provider_payment_methods) { %w[card] }

      before do
        allow(::Stripe::Customer).to receive(:create_funding_instructions)
      end

      it "does not fetch Stripe funding instructions" do
        sync_funding_service.call
        expect(::Stripe::Customer).not_to have_received(:create_funding_instructions)
      end
    end

    context "when customer is eligible and everything is valid and section does not yet exist" do
      let(:bank_transfer_data) { instance_double("BankTransfer", to_hash: {some: "details"}) }
      let(:funding_instructions) { instance_double("FundingInstructions", bank_transfer: bank_transfer_data) }

      let(:formatter_service_result) { instance_double("FormatterResult", details: "formatted bank details") }
      let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }

      before do
        allow(::Stripe::Customer).to receive(:create_funding_instructions).and_return(funding_instructions)
        allow(InvoiceCustomSections::FundingInstructionsFormatterService).to receive(:call)
          .and_return(formatter_service_result)
        allow(InvoiceCustomSections::CreateService).to receive(:call)
          .and_return(instance_double("CreateResult", invoice_custom_section: invoice_custom_section))
        allow(Customers::ManageInvoiceCustomSectionsService).to receive(:call)
        allow(payment_provider).to receive(:secret_key).and_return("sk_test_123")
      end

      it "creates the section and returns success" do
        result = sync_funding_service.call

        expect(result).to be_success
        expect(::Stripe::Customer).to have_received(:create_funding_instructions)
        expect(InvoiceCustomSections::FundingInstructionsFormatterService).to have_received(:call)
        expect(InvoiceCustomSections::CreateService).to have_received(:call)
        expect(Customers::ManageInvoiceCustomSectionsService).to have_received(:call)
      end
    end

    context "when customer country is unsupported but billing entity country is supported" do
      let(:billing_entity) { create(:billing_entity, organization:, country: "IE") }
      let(:customer) { create(:customer, organization:, currency: "EUR", country: "SE", billing_entity:) }
      let(:bank_transfer_data) { instance_double("BankTransfer", to_hash: {some: "details"}) }
      let(:funding_instructions) { instance_double("FundingInstructions", bank_transfer: bank_transfer_data) }
      let(:invoice_custom_section) { build_stubbed(:invoice_custom_section, organization:) }

      before do
        allow(::Stripe::Customer).to receive(:create_funding_instructions).and_return(funding_instructions)
        allow(InvoiceCustomSections::FundingInstructionsFormatterService).to receive(:call)
          .and_return(instance_double("FormatterResult", details: "formatted"))
        allow(InvoiceCustomSections::CreateService).to receive(:call)
          .and_return(instance_double("CreateResult", invoice_custom_section: invoice_custom_section))
        allow(Customers::ManageInvoiceCustomSectionsService).to receive(:call)
        allow(payment_provider).to receive(:secret_key).and_return("sk_test_123")
      end

      it "uses billing entity country" do
        sync_funding_service.call

        expect(::Stripe::Customer).to have_received(:create_funding_instructions).with(
          provider_customer_id,
          hash_including(
            bank_transfer: {
              type: "eu_bank_transfer",
              eu_bank_transfer: {country: "IE"}
            },
            currency: "eur",
            funding_type: "bank_transfer"
          ),
          {api_key: "sk_test_123"}
        )
      end
    end
  end
end
