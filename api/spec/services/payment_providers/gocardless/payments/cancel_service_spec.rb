# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Gocardless::Payments::CancelService do
  subject(:result) { described_class.call(payment:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:payment_provider) { create(:gocardless_provider, organization:, access_token: "gc_test_token") }
  let(:provider_customer) { create(:gocardless_customer, customer:, payment_provider:) }
  let(:payment) do
    create(:payment, payable: invoice, payment_provider:, payment_provider_customer: provider_customer,
      organization:, customer:, provider_payment_id: "PM123",
      payable_payment_status: :pending, status: "pending_submission")
  end

  let(:gocardless_client) { instance_double(GoCardlessPro::Client) }
  let(:gocardless_payments_service) { instance_double(GoCardlessPro::Services::PaymentsService) }

  before do
    allow(GoCardlessPro::Client).to receive(:new).and_return(gocardless_client)
    allow(gocardless_client).to receive(:payments).and_return(gocardless_payments_service)
  end

  context "when the payment is cancelable" do
    let(:cancel_response) do
      instance_double(GoCardlessPro::Resources::Payment, id: "PM123", status: "cancelled")
    end

    before do
      allow(gocardless_payments_service).to receive(:cancel).and_return(cancel_response)
    end

    it "calls the GoCardless cancel endpoint with the payment's provider id" do
      result

      expect(gocardless_payments_service).to have_received(:cancel).with("PM123")
    end

    it "constructs the client with the provider's access token and environment" do
      result

      expect(GoCardlessPro::Client).to have_received(:new).with(
        access_token: "gc_test_token",
        environment: payment_provider.environment
      )
    end

    it "returns a successful result with the payment" do
      expect(result).to be_success
      expect(result.payment).to eq(payment)
    end

    it "writes the cancelled status from the response onto the payment" do
      result

      expect(payment.reload.status).to eq("cancelled")
    end

    it "maps the cancelled status to a failed payable_payment_status" do
      result

      expect(payment.reload.payable_payment_status).to eq("failed")
    end
  end

  context "when GoCardless raises InvalidStateError with code cancellation_failed" do
    before do
      allow(gocardless_payments_service).to receive(:cancel)
        .and_raise(GoCardlessPro::InvalidStateError.new(
          "message" => "This payment cannot be cancelled, its status is submitted",
          "code" => "cancellation_failed"
        ))
    end

    it "returns a successful result with the payment" do
      expect(result).to be_success
      expect(result.payment).to eq(payment)
    end

    it "logs the underlying error message" do
      allow(Rails.logger).to receive(:info)

      result

      expect(Rails.logger).to have_received(:info)
        .with(a_string_matching(/GoCardless.*not cancelable.*status is submitted/))
    end

    it "does not mutate the payment record" do
      expect { result }.not_to change { payment.reload.attributes }
    end
  end

  context "when GoCardless raises InvalidStateError with a different code" do
    before do
      allow(gocardless_payments_service).to receive(:cancel)
        .and_raise(GoCardlessPro::InvalidStateError.new(
          "message" => "Mandate is inactive",
          "code" => "mandate_is_inactive"
        ))
    end

    it "propagates the error so the caller can retry or surface the failure" do
      expect { result }.to raise_error(GoCardlessPro::InvalidStateError)
    end
  end

  context "when GoCardless raises a generic error" do
    before do
      allow(gocardless_payments_service).to receive(:cancel)
        .and_raise(GoCardlessPro::Error.new(
          "message" => "Internal server error",
          "code" => "server_error"
        ))
    end

    it "propagates the error so the caller can retry" do
      expect { result }.to raise_error(GoCardlessPro::Error)
    end
  end

  context "when a Faraday connection failure occurs" do
    before do
      allow(gocardless_payments_service).to receive(:cancel)
        .and_raise(Faraday::ConnectionFailed.new("connection refused"))
    end

    it "wraps the error as Invoices::Payments::ConnectionError so the caller can retry" do
      expect { result }.to raise_error(Invoices::Payments::ConnectionError)
    end
  end
end
