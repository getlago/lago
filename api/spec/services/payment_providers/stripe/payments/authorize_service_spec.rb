# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::Payments::AuthorizeService do
  subject(:authorize_service) { described_class.new(amount:, currency:, provider_customer:, payment_method:, unique_id:, metadata:) }

  let(:amount) { 0.20 }
  let(:currency) { "USD" }
  let(:provider_customer) { create(:stripe_customer, payment_provider: create(:stripe_provider), customer:, payment_method_id:) }
  let(:payment_method) { create(:payment_method, payment_provider_customer: provider_customer, provider_method_id:) }
  let(:unique_id) { SecureRandom.uuid }
  let(:metadata) { {} }

  let(:customer) { create(:customer) }
  let(:provider_method_id) { "pm_from_payment_method" }
  let(:payment_method_id) { "pm_from_provider_customer" }
  let(:stripe_result) do
    result = BaseService::Result.new
    result.payment_method_id = "pm_from_stripe"
    result
  end

  before do
    allow(PaymentProviderCustomers::Stripe::RetrieveLatestPaymentMethodService).to receive(:call!).and_return(stripe_result)
  end

  describe ".call" do
    context "without provider_method_id" do
      let(:payment_method) { nil }
      let(:payment_method_id) { nil }
      let(:stripe_result) do
        result = BaseService::Result.new
        result.payment_method_id = nil
        result
      end

      it "fails" do
        result = subject.call

        expect(result).not_to be_success
      end
    end

    context "with provider_method_id" do
      let(:payment_intent) do
        Stripe::PaymentIntent.construct_from(
          id: "pi_#{SecureRandom.hex(6)}"
        )
      end

      before { allow(::Stripe::PaymentIntent).to receive(:create).and_return(payment_intent) }

      it "creates the stripe payment intent" do
        result = subject.call

        expect(result).to be_success
        expect(result.stripe_payment_intent).to be(payment_intent)
      end

      it "cancels the payment intent later" do
        subject.call

        expect(PaymentProviders::CancelPaymentAuthorizationJob).to have_been_enqueued
      end
    end
  end

  describe "private" do
    describe "#find_provider_method_id" do
      let(:result) { subject.send(:find_provider_method_id) }

      context "with payment_method" do
        it "uses payment_method#provider_method_id" do
          expect(result).to eq(provider_method_id)
        end
      end

      context "without payment_method" do
        let(:payment_method) { nil }

        it "uses provider_customer#payment_method_id" do
          expect(result).to eq(payment_method_id)
        end
      end

      context "when none is available" do
        let(:payment_method) { nil }
        let(:payment_method_id) { nil }

        it "fetch stripe default payment method" do
          expect(result).to eq("pm_from_stripe")
        end
      end
    end
  end
end
