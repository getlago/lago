# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Gocardless::Payments::CreateService do
  subject(:create_service) { described_class.new(payment:, reference:, metadata:) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:gocardless_payment_provider) { create(:gocardless_provider, organization:, code:) }
  let(:gocardless_customer) { create(:gocardless_customer, customer:, payment_provider: gocardless_payment_provider) }
  let(:gocardless_client) { instance_double(GoCardlessPro::Client) }
  let(:gocardless_payments_service) { instance_double(GoCardlessPro::Services::PaymentsService) }
  let(:gocardless_mandates_service) { instance_double(GoCardlessPro::Services::MandatesService) }
  let(:gocardless_list_response) { instance_double(GoCardlessPro::ListResponse) }
  let(:code) { "gocardless_1" }
  let(:reference) { "organization.name - Invoice #{invoice.number}" }
  let(:metadata) do
    {
      lago_customer_id: customer.id,
      lago_invoice_id: invoice.id,
      invoice_issuing_date: invoice.issuing_date.iso8601,
      invoice_type: invoice.invoice_type
    }
  end

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 200,
      currency: "EUR",
      ready_for_payment_processing: true
    )
  end

  let(:payment) do
    create(
      :payment,
      payable: invoice,
      status: "pending",
      payment_provider: gocardless_payment_provider,
      payment_provider_customer: gocardless_customer,
      amount_cents: invoice.total_amount_cents,
      amount_currency: invoice.currency
    )
  end

  describe ".call" do
    before do
      gocardless_customer

      allow(GoCardlessPro::Client).to receive(:new)
        .and_return(gocardless_client)
      allow(gocardless_client).to receive(:mandates)
        .and_return(gocardless_mandates_service)
      allow(gocardless_mandates_service).to receive(:list)
        .and_return(gocardless_list_response)
      allow(gocardless_list_response).to receive(:records)
        .and_return([GoCardlessPro::Resources::Mandate.new("id" => "mandate_id")])
      allow(gocardless_client).to receive(:payments)
        .and_return(gocardless_payments_service)
      allow(gocardless_payments_service).to receive(:create)
        .and_return(GoCardlessPro::Resources::Payment.new(
          "id" => "_ID_",
          "amount" => invoice.total_amount_cents,
          "currency" => invoice.currency,
          "status" => "paid_out"
        ))
      allow(Invoices::PrepaidCreditJob).to receive(:perform_later)
    end

    it "creates a gocardless payment" do
      result = create_service.call

      expect(result).to be_success

      expect(result.payment.id).to be_present
      expect(result.payment.payable).to eq(invoice)
      expect(result.payment.payment_provider).to eq(gocardless_payment_provider)
      expect(result.payment.payment_provider_customer).to eq(gocardless_customer)
      expect(result.payment.amount_cents).to eq(invoice.total_amount_cents)
      expect(result.payment.amount_currency).to eq(invoice.currency)
      expect(result.payment.status).to eq("paid_out")
      expect(result.payment.payable_payment_status).to eq("succeeded")
      expect(gocardless_customer.reload.provider_mandate_id).to eq("mandate_id")

      expect(gocardless_payments_service).to have_received(:create)
    end

    context "with error on gocardless" do
      let(:customer) { create(:customer, organization:, payment_provider_code: code) }

      let(:subscription) do
        create(:subscription, organization:, customer:)
      end

      let(:organization) do
        create(:organization, webhook_url: "https://webhook.com")
      end

      before do
        subscription

        allow(gocardless_payments_service).to receive(:create)
          .and_raise(GoCardlessPro::Error.new("code" => "code", "message" => "error"))
      end

      it "returns a failed result" do
        result = create_service.call

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("gocardless_error")
        expect(result.error.error_message).to eq("code: error")

        expect(result.error_message).to eq("error")
        expect(result.error_code).to eq("code")
        expect(result.payment.payable_payment_status).to eq("failed")
      end
    end

    context "when customer has no mandate to make a payment" do
      let(:customer) { create(:customer, organization:, payment_provider_code: code) }
      let(:organization) { create(:organization, webhook_url: "https://webhook.com") }

      before do
        allow(gocardless_list_response).to receive(:records)
          .and_return([])

        allow(gocardless_payments_service).to receive(:create)
          .and_raise(GoCardlessPro::Error.new("code" => "code", "message" => "error"))
      end

      it "delivers an error webhook" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("gocardless_error")
        expect(result.error.error_message).to eq("no_mandate_error: No mandate available for payment")

        expect(result.error_message).to eq("No mandate available for payment")
        expect(result.error_code).to eq("no_mandate_error")
        expect(result.payment.payable_payment_status).to eq("failed")
      end
    end

    context "when payment has a payment method" do
      let(:default_payment_method) { create(:payment_method, customer:, provider_method_id: "mandate_id2") }

      before do
        payment.update!(payment_method: default_payment_method)
        gocardless_customer.update!(provider_mandate_id: "mandate_id2")
      end

      it "creates a gocardless payment" do
        result = create_service.call

        expect(result).to be_success

        expect(result.payment.id).to be_present
        expect(result.payment.payable).to eq(invoice)
        expect(result.payment.payment_provider).to eq(gocardless_payment_provider)
        expect(result.payment.payment_provider_customer).to eq(gocardless_customer)
        expect(result.payment.amount_cents).to eq(invoice.total_amount_cents)
        expect(result.payment.amount_currency).to eq(invoice.currency)
        expect(result.payment.status).to eq("paid_out")
        expect(result.payment.payable_payment_status).to eq("succeeded")
        expect(gocardless_customer.reload.provider_mandate_id).to eq("mandate_id2")
        expect(gocardless_payments_service).to have_received(:create)
      end
    end
  end
end
