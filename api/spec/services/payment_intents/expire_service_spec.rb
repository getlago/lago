# frozen_string_literal: true

RSpec.describe PaymentIntents::ExpireService do
  describe ".call" do
    subject(:result) { described_class.call(invoice:) }

    let(:invoice) { create(:invoice) }
    let(:payment_provider_service) { instance_double("PaymentProviderService") }

    before do
      allow(Invoices::Payments::PaymentProviders::Factory)
        .to receive(:new_instance)
        .with(invoice:)
        .and_return(payment_provider_service)

      allow(payment_provider_service)
        .to receive(:expire_payment_url)
        .and_return(BaseService::Result.new)
    end

    context "when an active payment intent has a provider session id" do
      let!(:payment_intent) { create(:payment_intent, invoice:, provider_session_id: "cs_123") }

      it "expires the provider checkout session and the payment intent" do
        expect { result }.to change { payment_intent.reload.status }.from("active").to("expired")
        expect(payment_provider_service).to have_received(:expire_payment_url).with(payment_intent)
      end
    end

    context "when an active payment intent has no provider session id" do
      let!(:payment_intent) { create(:payment_intent, invoice:, provider_session_id: nil) }

      it "expires the payment intent without calling the provider" do
        expect { result }.to change { payment_intent.reload.status }.from("active").to("expired")
        expect(payment_provider_service).not_to have_received(:expire_payment_url)
      end
    end

    context "when there is no active payment intent" do
      let!(:expired_intent) { create(:payment_intent, :expired, invoice:, provider_session_id: "cs_123") }

      it "does nothing" do
        result

        expect(expired_intent.reload.status).to eq("expired")
        expect(payment_provider_service).not_to have_received(:expire_payment_url)
      end
    end
  end
end
