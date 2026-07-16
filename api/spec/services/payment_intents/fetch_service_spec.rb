# frozen_string_literal: true

RSpec.describe PaymentIntents::FetchService do
  describe ".call" do
    subject(:result) { described_class.call(invoice:) }

    context "when invoice does not exist" do
      let(:invoice) { nil }

      it "fails with invoice not found error" do
        expect(result).to be_failure
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when invoice exists" do
      let(:invoice) { create(:invoice) }
      let(:payment_provider_service) { instance_double("PaymentProviderService") }
      let(:payment_url) { "https://example.com/payment" }

      before do
        allow(Invoices::Payments::PaymentProviders::Factory)
          .to receive(:new_instance)
          .with(invoice:)
          .and_return(payment_provider_service)

        allow(payment_provider_service)
          .to receive(:generate_payment_url)
          .with(instance_of(PaymentIntent))
          .and_return(BaseService::Result.new.tap { |r| r.payment_url = payment_url })
      end

      context "when active payment intent exists" do
        let!(:payment_intent) { create(:payment_intent, invoice:, payment_url:) }

        it "returns the existing payment intent" do
          expect(result).to be_success
          expect(result.payment_intent).to eq(payment_intent)
          expect(payment_provider_service).not_to have_received(:generate_payment_url)
        end
      end

      context "when payment intent exists but has no payment URL" do
        let!(:payment_intent) { create(:payment_intent, invoice:, payment_url: nil) }

        it "returns intent with generated payment URL" do
          expect(result).to be_success
          expect(result.payment_intent).to eq(payment_intent)
          expect(result.payment_intent.payment_url).to eq(payment_url)
          expect(payment_provider_service).to have_received(:generate_payment_url)
        end

        it "persists the provider session id returned by the provider" do
          allow(payment_provider_service)
            .to receive(:generate_payment_url)
            .and_return(BaseService::Result.new.tap do |r|
              r.payment_url = payment_url
              r.provider_session_id = "cs_123"
            end)

          expect(result.payment_intent.provider_session_id).to eq("cs_123")
        end
      end

      context "when payment provider fails to generate URL" do
        before do
          allow(payment_provider_service)
            .to receive(:generate_payment_url)
            .and_return(BaseService::Result.new.tap { |r| r.payment_url = nil })
        end

        it "fails with payment provider error" do
          expect(result).to be_failure
          expect(result.error.messages).to eq({base: ["payment_provider_error"]})
        end
      end

      context "when awaiting expiration payment intent exists" do
        let!(:awaiting_expiration_intent) { create(:payment_intent, :awaiting_expiration, invoice:) }

        it "expires awaiting expiration payment intent" do
          expect { result }.to change { awaiting_expiration_intent.reload.status }.to("expired")
        end

        it "returns new payment intent" do
          expect(result).to be_success
          expect(result.payment_intent.payment_url).to eq(payment_url)
          expect(payment_provider_service).to have_received(:generate_payment_url)
        end
      end
    end
  end
end
