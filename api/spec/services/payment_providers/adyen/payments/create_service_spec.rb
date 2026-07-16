# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Adyen::Payments::CreateService do
  subject(:create_service) { described_class.new(payment:, reference:, metadata:) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:adyen_payment_provider) { create(:adyen_provider, organization:, code:) }
  let(:adyen_customer) { create(:adyen_customer, customer:, payment_provider: adyen_payment_provider) }
  let(:adyen_client) { instance_double(Adyen::Client) }
  let(:payments_api) { Adyen::PaymentsApi.new(adyen_client, 70) }
  let(:payment_links_api) { Adyen::PaymentLinksApi.new(adyen_client, 70) }
  let(:payment_links_response) { generate(:adyen_payment_links_response) }
  let(:checkout) { Adyen::Checkout.new(adyen_client, 70) }
  let(:payments_response) { generate(:adyen_payments_response) }
  let(:payment_methods_response) { generate(:adyen_payment_methods_response) }
  let(:code) { "adyen_1" }
  let(:reference) { "organization.name - Invoice #{invoice.number}" }
  let(:metadata) do
    {
      lago_customer_id: customer.id,
      lago_invoice_id: invoice.id,
      invoice_issuing_date: invoice.issuing_date.iso8601,
      invoice_type: invoice.invoice_type
    }
  end
  let(:payment_method) { nil }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 1000,
      currency: "USD",
      ready_for_payment_processing: true
    )
  end

  let(:payment) do
    create(
      :payment,
      payable: invoice,
      status: "pending",
      payment_provider: adyen_payment_provider,
      payment_provider_customer: adyen_customer,
      amount_cents: invoice.total_amount_cents,
      amount_currency: invoice.currency,
      payment_method:
    )
  end

  describe "#call" do
    before do
      adyen_payment_provider
      adyen_customer

      allow(::Adyen::Client).to receive(:new)
        .and_return(adyen_client)
      allow(adyen_client).to receive(:checkout)
        .and_return(checkout)
      allow(checkout).to receive(:payments_api)
        .and_return(payments_api)
      allow(payments_api).to receive(:payments)
        .and_return(payments_response)
      allow(payments_api).to receive(:payment_methods)
        .and_return(payment_methods_response)
    end

    it "creates an adyen payment" do
      result = create_service.call

      expect(result).to be_success
      expect(result.payment.id).to be_present
      expect(result.payment.payable).to eq(invoice)
      expect(result.payment.payment_provider).to eq(adyen_payment_provider)
      expect(result.payment.payment_provider_customer).to eq(adyen_customer)
      expect(result.payment.amount_cents).to eq(invoice.total_amount_cents)
      expect(result.payment.amount_currency).to eq(invoice.currency)
      expect(result.payment.status).to eq("Authorised")
      expect(result.payment.payable_payment_status).to eq("succeeded")

      expect(adyen_customer.reload.payment_method_id)
        .to eq(payment_methods_response.response["storedPaymentMethods"].first["id"])

      expect(payments_api).to have_received(:payments)
    end

    context "when payment has a payment method" do
      let(:payment_method) { create(:payment_method, payment_provider_customer: adyen_customer, provider_method_id: "pm_test") }

      it "uses payment method provider id" do
        result = create_service.call

        expect(result).to be_success
        expect(result.payment.id).to be_present
        expect(payments_api).to have_received(:payments)
          .with(
            hash_including(
              paymentMethod: hash_including(storedPaymentMethodId: "pm_test")
            ), anything
          )
      end
    end

    context "with error response from adyen" do
      let(:payments_error_response) { generate(:adyen_payments_error_response) }

      before do
        allow(payments_api).to receive(:payments).and_return(payments_error_response)
      end

      it "returns a failed result" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("adyen_error")
        expect(result.error.error_message)
          .to eq("validation: There are no payment methods available for the given parameters.")

        expect(result.error_message).to eq("There are no payment methods available for the given parameters.")
        expect(result.error_code).to eq("validation")
        expect(result.payment.status).to eq("failed")
        expect(result.payment.payable_payment_status).to eq("failed")
      end
    end

    context "with validation error on adyen" do
      let(:customer) { create(:customer, organization:, payment_provider_code: code) }

      let(:subscription) do
        create(:subscription, organization:, customer:)
      end

      let(:organization) do
        create(:organization, webhook_url: "https://webhook.com")
      end

      before do
        subscription
      end

      context "when changing payment method fails with invalid card" do
        before do
          allow(payments_api).to receive(:payment_methods)
            .and_raise(Adyen::ValidationError.new("Invalid card number", nil))
        end

        it "returns a failed result" do
          result = create_service.call

          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("adyen_error")
          expect(result.error.error_message).to eq(": Invalid card number")

          expect(result.error_message).to eq("Invalid card number")
          expect(result.error_code).to be_nil
          expect(result.payment.status).to eq("failed")
          expect(result.payment.payable_payment_status).to eq("failed")
        end
      end

      context "when payment fails with invalid card" do
        before do
          allow(payments_api).to receive(:payments)
            .and_raise(Adyen::ValidationError.new("Invalid card number", nil))
        end

        it "returns a success result with error messages" do
          result = create_service.call

          expect(result.error).to be_a(BaseService::ServiceFailure)
          expect(result.error.code).to eq("adyen_error")
          expect(result.error.error_message).to eq(": Invalid card number")

          expect(result.error_message).to eq("Invalid card number")
          expect(result.error_code).to be_nil
          expect(result.payment.status).to eq("failed")
          expect(result.payment.payable_payment_status).to eq("failed")
        end
      end
    end

    context "with error on adyen" do
      let(:customer) { create(:customer, organization:, payment_provider_code: code) }

      let(:subscription) do
        create(:subscription, organization:, customer:)
      end

      let(:organization) do
        create(:organization, webhook_url: "https://webhook.com")
      end

      before do
        subscription

        allow(payments_api).to receive(:payments)
          .and_raise(Adyen::AdyenError.new(nil, nil, "error", "code"))
      end

      it "returns a failed result" do
        result = create_service.call

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("adyen_error")
        expect(result.error.error_message).to eq("code: error")

        expect(result.error_message).to eq("error")
        expect(result.error_code).to eq("code")
        expect(result.payment.payable_payment_status).to eq("failed")
      end
    end
  end
end
