# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::HandleEventService do
  subject(:event_service) { described_class.new(organization:, event_json:) }

  let(:organization) { create(:organization) }

  let(:payment_service) { instance_double(Invoices::Payments::StripeService) }
  let(:provider_customer_service) { instance_double(PaymentProviderCustomers::StripeService) }
  let(:service_result) { BaseService::Result.new }

  before do
    allow(Invoices::Payments::StripeService).to receive(:new)
      .and_return(payment_service)
    allow(payment_service).to receive(:update_payment_status)
      .and_return(service_result)
  end

  context "when setup intent event" do
    let(:event_json) do
      get_stripe_fixtures("webhooks/setup_intent_succeeded.json")
    end

    before do
      allow(PaymentProviders::Stripe::Webhooks::SetupIntentSucceededService).to receive(:call)
        .and_return(service_result)
    end

    it "routes the event to an other service" do
      result = event_service.call

      expect(result).to be_success

      expect(PaymentProviders::Stripe::Webhooks::SetupIntentSucceededService).to have_received(:call)
    end
  end

  context "when customer updated event" do
    let(:event_json) do
      get_stripe_fixtures("webhooks/customer_updated.json")
    end

    before do
      allow(PaymentProviders::Stripe::Webhooks::CustomerUpdatedService).to receive(:call)
        .and_return(service_result)
    end

    it "routes the event to an other service" do
      result = event_service.call

      expect(result).to be_success

      expect(PaymentProviders::Stripe::Webhooks::CustomerUpdatedService).to have_received(:call)
    end
  end

  context "when payment method detached event" do
    let(:event_json) { get_stripe_fixtures("webhooks/payment_method_detached.json") }

    before do
      allow(PaymentProviderCustomers::StripeService).to receive(:new)
        .and_return(provider_customer_service)
      allow(provider_customer_service).to receive(:delete_payment_method)
        .and_return(service_result)
    end

    it "routes the event to an other service" do
      result = event_service.call

      expect(result).to be_success

      expect(PaymentProviderCustomers::StripeService).to have_received(:new)
      expect(provider_customer_service).to have_received(:delete_payment_method)
    end
  end

  context "when refund updated event" do
    let(:refund_service) { instance_double(CreditNotes::Refunds::StripeService) }

    let(:event_json) do
      get_stripe_fixtures("webhooks/charge_refund_updated.json")
    end

    before do
      allow(CreditNotes::Refunds::StripeService).to receive(:new)
        .and_return(refund_service)
      allow(refund_service).to receive(:update_status)
        .and_return(service_result)
    end

    it "routes the event to an other service" do
      result = event_service.call

      expect(result).to be_success

      expect(CreditNotes::Refunds::StripeService).to have_received(:new)
      expect(refund_service).to have_received(:update_status)
    end
  end

  context "when event does not match an expected event type" do
    let(:event_json) do
      {
        id: "foo",
        type: "invalid",
        data: {
          object: {id: "foo"}
        }
      }.to_json
    end

    it "returns an empty result" do
      result = event_service.call

      expect(result).to be_success

      expect(Invoices::Payments::StripeService).not_to have_received(:new)
      expect(payment_service).not_to have_received(:update_payment_status)
    end
  end
end
