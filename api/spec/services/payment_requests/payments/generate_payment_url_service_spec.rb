# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::Payments::GeneratePaymentUrlService do
  subject(:generate_payment_url_service) { described_class.new(payable: payment_request) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:, payment_provider: provider, payment_provider_code: code) }
  let(:payment_request) { create(:payment_request, customer:) }
  let(:provider) { "stripe" }
  let(:code) { "stripe_1" }
  let(:payment_provider) { create(:stripe_provider, code:, organization:) }
  let(:provider_customer) { create(:stripe_customer, payment_provider:, customer:) }

  describe ".call" do
    before do
      provider_customer

      allow(::Stripe::Checkout::Session).to receive(:create)
        .and_return({"url" => "https://example55.com"})
    end

    it "returns the generated payment url" do
      result = generate_payment_url_service.call

      expect(result.payment_url).to eq("https://example55.com")
    end

    context "when payment provider is blank" do
      let(:provider) { nil }

      it "returns an error" do
        result = generate_payment_url_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:base]).to eq(["no_linked_payment_provider"])
      end
    end

    context "when payment provider is gocardless" do
      let(:provider) { "gocardless" }

      it "returns an error" do
        result = generate_payment_url_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:base]).to eq(["invalid_payment_provider"])
      end
    end

    context "when payment request's payment status is invalid" do
      before { payment_request.payment_succeeded! }

      it "returns an error" do
        result = generate_payment_url_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:base]).to eq(["invalid_payment_status"])
      end
    end
  end

  context "when payment provider is missing" do
    let(:payment_provider) { nil }
    let(:provider_customer) { nil }

    it "returns an error" do
      result = generate_payment_url_service.call

      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages[:base]).to eq(["missing_payment_provider"])
    end
  end

  context "when payment provider customer is missing" do
    let(:provider_customer) { nil }

    before { payment_provider }

    it "returns an error" do
      result = generate_payment_url_service.call

      expect(result).not_to be_success
      expect(result.error).to be_a(BaseService::ValidationFailure)
      expect(result.error.messages[:base]).to eq(["missing_payment_provider_customer"])
    end
  end

  context "when provider service return a third party error" do
    let(:provider) { "cashfree" }
    let(:code) { "cashfree_1" }

    let(:payment_provider_service) { instance_double(PaymentRequests::Payments::CashfreeService) }
    let(:payment_provider) { create(:cashfree_provider, code:, organization:) }
    let(:provider_customer) { create(:cashfree_customer, payment_provider:, customer:) }

    let(:error_result) do
      BaseService::Result.new.tap do |result|
        result.fail_with_error!(
          BaseService::ThirdPartyFailure.new(
            result,
            third_party: "Cashfree",
            error_code: "400",
            error_message: '{"code: "link_post_failed", "type": "invalid_request_error"}'
          )
        )
      end
    end

    before do
      allow(PaymentRequests::Payments::CashfreeService)
        .to receive(:new)
        .and_return(payment_provider_service)

      allow(payment_provider_service).to receive(:generate_payment_url)
        .and_return(error_result)
    end

    it "delivers an error webhook" do
      expect { generate_payment_url_service.call }
        .to enqueue_job(SendWebhookJob)
        .with(
          "payment_request.payment_failure",
          payment_request,
          provider_customer_id: provider_customer.provider_customer_id,
          provider_error: {
            message: '{"code: "link_post_failed", "type": "invalid_request_error"}',
            error_code: "400"
          }
        ).on_queue(webhook_queue)
    end

    it "returns a third party error" do
      result = generate_payment_url_service.call

      expect(result).to eq(error_result)
    end
  end

  context "when provider service return an error" do
    let(:payment_provider_service) { instance_double(Invoices::Payments::StripeService) }

    let(:error_result) do
      BaseService::Result.new.tap do |result|
        result.fail_with_error!(
          BaseService::ServiceFailure.new(
            result,
            code: "400",
            error_message: "error"
          )
        )
      end
    end

    before do
      allow(Invoices::Payments::StripeService)
        .to receive(:new)
        .and_return(payment_provider_service)

      allow(payment_provider_service).to receive(:generate_payment_url)
        .and_return(error_result)
    end

    it "returns an error" do
      result = generate_payment_url_service.call

      expect(result).to eq(error_result)
    end
  end
end
