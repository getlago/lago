# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::FlutterwaveService do
  subject(:flutterwave_service) { described_class.new(invoice) }

  let(:organization) { create(:organization, name: "Test Organization") }
  let(:customer) { create(:customer, organization: organization, email: "customer@example.com", name: "John Doe") }
  let(:flutterwave_provider) { create(:flutterwave_provider, organization: organization, secret_key: "FLWSECK_TEST-secret") }
  let(:flutterwave_customer) { create(:flutterwave_customer, customer: customer, payment_provider: flutterwave_provider) }
  let(:invoice) { create(:invoice, organization: organization, customer: customer, total_amount_cents: 50000, currency: "USD", number: "INV-001") }

  before do
    flutterwave_customer
  end

  describe "#update_payment_status" do
    let(:flutterwave_payment) do
      OpenStruct.new(
        id: "flw_payment_123",
        metadata: {
          payment_type: "one-time",
          lago_invoice_id: invoice.id
        }
      )
    end

    context "when creating a new payment" do
      it "creates a new payment and updates invoice status" do
        result = flutterwave_service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )

        expect(result).to be_success
        expect(result.payment).to be_a(Payment)
        expect(result.payment.provider_payment_id).to eq("flw_payment_123")
        expect(result.payment.amount_cents).to eq(invoice.total_due_amount_cents)
        expect(result.payment.payable).to eq(invoice)
        expect(result.invoice).to eq(invoice)
      end

      it "increments payment attempts on the invoice" do
        expect { flutterwave_service.update_payment_status(organization_id: organization.id, status: :succeeded, flutterwave_payment: flutterwave_payment) }
          .to change { invoice.reload.payment_attempts }.by(1)
      end

      it "sets correct payment details" do
        result = flutterwave_service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )

        payment = result.payment
        expect(payment.organization_id).to eq(organization.id)
        expect(payment.payment_provider_id).to eq(flutterwave_provider.id)
        expect(payment.payment_provider_customer_id).to eq(flutterwave_customer.id)
        expect(payment.amount_currency).to eq("USD")
      end

      it "enqueues a SendWebhookJob for payment.succeeded" do
        expect do
          flutterwave_service.update_payment_status(
            organization_id: organization.id,
            status: :succeeded,
            flutterwave_payment: flutterwave_payment
          )
        end.to have_enqueued_job(SendWebhookJob).with("payment.succeeded", Payment)
      end
    end

    context "when updating existing payment" do
      let(:existing_payment) do
        create(:payment,
          organization: organization,
          payable: invoice,
          payment_provider: flutterwave_provider,
          provider_payment_id: "flw_payment_123",
          status: :pending)
      end

      let(:flutterwave_payment) do
        OpenStruct.new(
          id: "flw_payment_123",
          metadata: {payment_type: "recurring"}
        )
      end

      before { existing_payment }

      it "updates the existing payment status" do
        result = flutterwave_service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )

        expect(result).to be_success
        expect(result.payment.id).to eq(existing_payment.id)
        expect(result.payment.status).to eq("succeeded")
      end

      it "updates invoice payment status" do
        allow(Invoices::UpdateService).to receive(:call).and_return(BaseService::Result.new)

        flutterwave_service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )
        expect(Invoices::UpdateService).to have_received(:call) do |args|
          expect(args[:invoice]).to eq(invoice)
          expect(args[:params][:payment_status]).to eq("succeeded")
          expect(args[:params][:ready_for_payment_processing]).to be false
        end
      end
    end

    context "when payment is not found" do
      let(:flutterwave_payment) do
        OpenStruct.new(
          id: "nonexistent_payment",
          metadata: {payment_type: "recurring"}
        )
      end

      it "returns not found failure" do
        result = flutterwave_service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
      end
    end

    context "when payment already succeeded" do
      let(:succeeded_invoice) { create(:invoice, organization: organization, customer: customer, payment_status: :succeeded) }
      let(:existing_payment) do
        create(:payment,
          organization: organization,
          payable: succeeded_invoice,
          payment_provider: flutterwave_provider,
          provider_payment_id: "flw_payment_123",
          status: :succeeded)
      end

      let(:flutterwave_payment) do
        OpenStruct.new(
          id: "flw_payment_123",
          metadata: {payment_type: "recurring"}
        )
      end

      before { existing_payment }

      it "returns early without processing" do
        service = described_class.new(succeeded_invoice)
        allow(service).to receive(:update_invoice_payment_status)

        result = service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )

        expect(result).to be_success
        expect(service).not_to have_received(:update_invoice_payment_status)
      end
    end

    context "when payment status calculation includes total paid amount" do
      let(:existing_payment1) { create(:payment, payable: invoice, amount_cents: 20000, payable_payment_status: :succeeded) }
      let(:existing_payment2) { create(:payment, payable: invoice, amount_cents: 15000, payable_payment_status: :succeeded) }

      before do
        existing_payment1
        existing_payment2
        allow(Invoices::UpdateService).to receive(:call).and_return(BaseService::Result.new)
      end

      it "calculates total paid amount correctly" do
        flutterwave_service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )

        expect(Invoices::UpdateService).to have_received(:call) do |args|
          expect(args[:params][:total_paid_amount_cents]).to eq(85000) # 20000 + 15000 + 50000 (new payment)
        end
      end
    end
  end

  describe "#generate_payment_url" do
    let(:payment_intent) { double }
    let(:http_client) { instance_double(LagoHttpClient::Client) }
    let(:successful_response) do
      instance_double("HTTPResponse", body: {
        status: "success",
        data: {
          link: "https://checkout.flutterwave.com/v3/hosted/pay/test_link"
        }
      }.to_json)
    end

    before do
      allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
      allow(http_client).to receive(:post_with_response).and_return(successful_response)
    end

    it "creates a checkout session and returns payment URL" do
      result = flutterwave_service.generate_payment_url(payment_intent)

      expect(result).to be_success
      expect(result.payment_url).to eq("https://checkout.flutterwave.com/v3/hosted/pay/test_link")
    end

    it "sends correct parameters to Flutterwave API" do
      flutterwave_service.generate_payment_url(payment_intent)

      expect(http_client).to have_received(:post_with_response) do |body, headers|
        expect(body[:amount]).to eq(500.0)
        expect(body[:tx_ref]).to eq(invoice.id)
        expect(body[:currency]).to eq("USD")
        expect(body[:customer][:email]).to eq("customer@example.com")
        expect(body[:customer][:name]).to eq("John Doe")
        expect(body[:customizations][:title]).to eq("Test Organization - Invoice Payment")
        expect(body[:customizations][:description]).to eq("Payment for Invoice #INV-001")
        expect(body[:meta][:lago_customer_id]).to eq(customer.id)
        expect(body[:meta][:lago_invoice_id]).to eq(invoice.id)
        expect(body[:meta][:lago_organization_id]).to eq(organization.id)
        expect(body[:meta][:lago_invoice_number]).to eq("INV-001")
        expect(body[:meta][:payment_type]).to eq("one-time")

        expect(headers["Authorization"]).to eq("Bearer FLWSECK_TEST-secret")
        expect(headers["Content-Type"]).to eq("application/json")
        expect(headers["Accept"]).to eq("application/json")
      end
    end

    context "when HTTP client raises an error" do
      let(:http_error) { LagoHttpClient::HttpError.new(500, "Connection failed", "https://api.example.com") }

      before do
        allow(http_client).to receive(:post_with_response).and_raise(http_error)
      end

      it "returns third party failure" do
        result = flutterwave_service.generate_payment_url(payment_intent)

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ThirdPartyFailure)
        expect(result.error.third_party).to eq("Flutterwave")
      end
    end
  end

  describe "private methods" do
    describe "#create_checkout_session" do
      let(:http_client) { instance_double(LagoHttpClient::Client) }

      before do
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:post_with_response).and_return(instance_double("HTTPResponse", body: '{"data": {"link": "test_link"}}'))
      end

      it "uses correct API endpoint" do
        flutterwave_service.send(:create_checkout_session)

        expect(LagoHttpClient::Client).to have_received(:new).with("#{flutterwave_provider.api_url}/payments")
      end

      it "handles different currencies correctly" do
        invoice.update!(currency: "NGN", total_amount_cents: 1000000)

        flutterwave_service.send(:create_checkout_session)

        expect(http_client).to have_received(:post_with_response) do |body|
          expect(body[:amount]).to eq(10000.0)
          expect(body[:currency]).to eq("NGN")
        end
      end
    end

    describe "#increment_payment_attempts" do
      it "increments payment attempts on invoice" do
        expect { flutterwave_service.send(:increment_payment_attempts) }
          .to change { invoice.reload.payment_attempts }.by(1)
      end
    end

    describe "#update_invoice_payment_status" do
      let(:payment) { create(:payment, payable: invoice) }

      before do
        flutterwave_service.instance_variable_set(:@result, BaseService::Result.new.tap { |r| r.invoice = invoice })
        allow(Invoices::UpdateService).to receive(:call).and_return(BaseService::Result.new)
      end

      it "calls invoice update service with correct parameters" do
        flutterwave_service.send(:update_invoice_payment_status, payment_status: :succeeded)

        expect(Invoices::UpdateService).to have_received(:call) do |args|
          expect(args[:invoice]).to eq(invoice)
          expect(args[:params][:payment_status]).to eq(:succeeded)
          expect(args[:params][:ready_for_payment_processing]).to be false
          expect(args[:webhook_notification]).to be true
        end
      end

      context "when payment status is not succeeded" do
        it "sets ready_for_payment_processing to true" do
          flutterwave_service.send(:update_invoice_payment_status, payment_status: :failed)

          expect(Invoices::UpdateService).to have_received(:call) do |args|
            expect(args[:params][:ready_for_payment_processing]).to be true
          end
        end
      end
    end
  end
end
