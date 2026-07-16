# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::Payments::FlutterwaveService do
  subject(:flutterwave_service) { described_class.new(payment_request) }

  let(:organization) { create(:organization, name: "Test Organization") }
  let(:customer) { create(:customer, organization: organization, email: "customer@example.com", name: "John Doe") }
  let(:flutterwave_provider) { create(:flutterwave_provider, organization: organization, secret_key: "FLWSECK_TEST-secret") }
  let(:flutterwave_customer) { create(:flutterwave_customer, customer: customer, payment_provider: flutterwave_provider) }
  let(:invoice) { create(:invoice, organization: organization, customer: customer, total_amount_cents: 50000, currency: "USD") }
  let(:payment_request) do
    create(
      :payment_request,
      organization:,
      customer:,
      total_amount_cents: 50000,
      currency: "USD",
      invoices: [invoice]
    )
  end

  before do
    flutterwave_customer
  end

  describe "#call" do
    let(:http_client) { instance_double(LagoHttpClient::Client) }
    let(:successful_response) do
      {
        "status" => "success",
        "data" => {
          "link" => "https://checkout.flutterwave.com/v3/hosted/pay/test_link"
        }
      }
    end

    before do
      allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
      allow(http_client).to receive(:post_with_response).and_return(successful_response)
    end

    it "creates a checkout session and returns payment URL" do
      result = flutterwave_service.call

      expect(result).to be_success
      expect(result.payment_url).to eq("https://checkout.flutterwave.com/v3/hosted/pay/test_link")
    end

    it "sends correct parameters to Flutterwave API" do
      flutterwave_service.call

      expect(http_client).to have_received(:post_with_response) do |body, headers|
        expect(body[:amount]).to eq(500.0)
        expect(body[:tx_ref]).to eq("lago_payment_request_#{payment_request.id}")
        expect(body[:currency]).to eq("USD")
        expect(body[:customer][:email]).to eq("customer@example.com")
        expect(body[:customer][:name]).to eq("John Doe")
        expect(body[:customizations][:title]).to eq("Test Organization - Payment Request")
        expect(body[:meta][:lago_customer_id]).to eq(customer.id)
        expect(body[:meta][:lago_payment_request_id]).to eq(payment_request.id)
        expect(body[:meta][:lago_organization_id]).to eq(organization.id)

        expect(headers["Authorization"]).to eq("Bearer FLWSECK_TEST-secret")
        expect(headers["Content-Type"]).to eq("application/json")
        expect(headers["Accept"]).to eq("application/json")
      end
    end

    context "when HTTP client raises an error" do
      let(:http_error) { LagoHttpClient::HttpError.new(500, "Connection failed", "https://api.example.com") }

      before do
        allow(http_client).to receive(:post_with_response).and_raise(http_error)
        allow(SendWebhookJob).to receive(:perform_later)
      end

      it "delivers error webhook and returns service failure" do
        result = flutterwave_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("action_script_runtime_error")
        expect(result.error.message).to include("Connection failed")
      end

      it "sends webhook notification about payment failure" do
        flutterwave_service.call

        expect(SendWebhookJob).to have_received(:perform_later).with(
          "payment_request.payment_failure",
          payment_request,
          provider_customer_id: flutterwave_customer.provider_customer_id,
          provider_error: {
            message: "HTTP 500 - URI: https://api.example.com.\nError: Connection failed\nResponse headers: {}",
            error_code: 500
          }
        )
      end
    end
  end

  describe "#update_payment_status" do
    let(:flutterwave_payment) do
      OpenStruct.new(
        id: "flw_payment_123",
        metadata: {
          payment_type: "one-time",
          lago_payable_id: payment_request.id
        }
      )
    end

    context "when creating a new payment" do
      it "creates a new payment and updates payment request status" do
        result = flutterwave_service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )

        expect(result).to be_success
        expect(result.payment).to be_a(Payment)
        expect(result.payment.provider_payment_id).to eq("flw_payment_123")
        expect(result.payment.amount_cents).to eq(50000)
        expect(result.payment.payable).to eq(payment_request)
        expect(result.payable).to eq(payment_request)
      end

      it "increments payment attempts on the payment request" do
        expect { flutterwave_service.update_payment_status(organization_id: organization.id, status: :succeeded, flutterwave_payment: flutterwave_payment) }
          .to change { payment_request.reload.payment_attempts }.by(1)
      end
    end

    context "when updating existing payment" do
      let(:existing_payment) do
        create(:payment,
          organization: organization,
          payable: payment_request,
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
      let(:succeeded_payment_request) { create(:payment_request, organization: organization, customer: customer, payment_status: :succeeded) }
      let(:existing_payment) do
        create(:payment,
          organization: organization,
          payable: succeeded_payment_request,
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
        service = described_class.new(payable: succeeded_payment_request)
        allow(service).to receive(:update_payable_payment_status)

        result = service.update_payment_status(
          organization_id: organization.id,
          status: :succeeded,
          flutterwave_payment: flutterwave_payment
        )

        expect(result).to be_success
        expect(service).not_to have_received(:update_payable_payment_status)
      end
    end

    context "when payment fails" do
      let(:flutterwave_payment) do
        OpenStruct.new(
          id: "flw_payment_123",
          metadata: {
            payment_type: "one-time",
            lago_payable_id: payment_request.id
          }
        )
      end

      before do
        mailer_with_double = instance_double("PaymentRequestMailer")
        mailer_message_double = instance_double("ActionMailer::MessageDelivery")

        allow(PaymentRequestMailer).to receive(:with).and_return(mailer_with_double)
        allow(mailer_with_double).to receive(:requested).and_return(mailer_message_double)
        allow(mailer_message_double).to receive(:deliver_later)
      end

      it "sends payment failure email" do
        flutterwave_service.update_payment_status(
          organization_id: organization.id,
          status: :failed,
          flutterwave_payment: flutterwave_payment
        )
        expect(PaymentRequestMailer).to have_received(:with).with(payment_request: payment_request)
      end
    end

    context "when a failed webhook arrives after the invoice was already paid through another path" do
      before do
        payment_request.payment_failed!
        invoice.payment_succeeded!
      end

      it "leaves the already-succeeded invoice untouched" do
        expect do
          flutterwave_service.update_payment_status(
            organization_id: organization.id,
            status: :failed,
            flutterwave_payment: flutterwave_payment
          )
        end.not_to change { invoice.reload.payment_status }

        expect(invoice.reload).to be_payment_succeeded
      end
    end
  end

  describe "private methods" do
    describe "#create_checkout_session" do
      let(:http_client) { instance_double(LagoHttpClient::Client) }

      before do
        allow(LagoHttpClient::Client).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:post_with_response).and_return({"data" => {"link" => "test_link"}})
      end

      it "uses correct currency conversion" do
        payment_request.update!(currency: "NGN", total_amount_cents: 1000000) # 10,000 NGN

        flutterwave_service.call

        expect(http_client).to have_received(:post_with_response) do |body|
          expect(body[:amount]).to eq(10000.0)
          expect(body[:currency]).to eq("NGN")
        end
      end

      it "includes correct meta parameters" do
        flutterwave_service.call

        expect(http_client).to have_received(:post_with_response) do |body|
          meta = body[:meta]
          expect(meta[:lago_customer_id]).to eq(customer.id)
          expect(meta[:lago_payment_request_id]).to eq(payment_request.id)
          expect(meta[:lago_organization_id]).to eq(organization.id)
          expect(meta[:lago_invoice_ids]).to eq(invoice.id.to_s)
        end
      end
    end
  end
end
