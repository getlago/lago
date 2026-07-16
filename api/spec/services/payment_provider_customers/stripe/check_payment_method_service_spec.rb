# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::Stripe::CheckPaymentMethodService do
  subject(:check_service) { described_class.new(stripe_customer:, payment_method_id:) }

  let(:customer) { create(:customer, organization:) }
  let(:stripe_provider) { create(:stripe_provider) }
  let(:organization) { stripe_provider.organization }

  let(:stripe_customer) do
    create(
      :stripe_customer,
      payment_provider: stripe_provider,
      customer:,
      provider_customer_id: "cus_123456",
      payment_method_id:
    )
  end

  let(:payment_method_id) { "card_12345" }
  let(:payment_method) { Stripe::PaymentMethod.new(id: payment_method_id) }
  let(:stripe_api_customer) { instance_double(Stripe::Customer) }

  before do
    allow(Stripe::Customer).to receive(:new)
      .and_return(stripe_api_customer)
  end

  describe "#call" do
    it "checks for the existence of the payment method" do
      allow(stripe_api_customer)
        .to receive(:retrieve_payment_method)
        .and_return(payment_method)

      result = check_service.call

      expect(result).to be_success
      expect(result.payment_method.id).to eq(payment_method_id)

      expect(Stripe::Customer).to have_received(:new)
      expect(stripe_api_customer).to have_received(:retrieve_payment_method)
    end

    context "when payment method is not found on stripe" do
      before do
        allow(stripe_api_customer)
          .to receive(:retrieve_payment_method)
          .and_raise(::Stripe::InvalidRequestError.new("error", {}))
      end

      it "returns a failed result" do
        result = check_service.call

        expect(result).not_to be_success

        expect(Stripe::Customer).to have_received(:new)
        expect(stripe_api_customer).to have_received(:retrieve_payment_method)
      end

      context "when a payment method exists" do
        let(:default_payment_method) { create(:payment_method, customer:, provider_method_id: payment_method_id) }

        before { default_payment_method }

        it "returns a failed result and discards payment method" do
          result = check_service.call

          expect(result).not_to be_success

          expect(Stripe::Customer).to have_received(:new)
          expect(stripe_api_customer).to have_received(:retrieve_payment_method)
          expect(default_payment_method.reload.deleted_at).to be_present
        end
      end
    end

    context "when customer is deleted" do
      let(:customer) { create(:customer, :deleted, organization:) }

      it "checks for the existence of the payment method" do
        allow(stripe_api_customer)
          .to receive(:retrieve_payment_method)
          .and_return(payment_method)

        result = check_service.call

        expect(result).to be_success
        expect(result.payment_method.id).to eq(payment_method_id)

        expect(Stripe::Customer).to have_received(:new)
        expect(stripe_api_customer).to have_received(:retrieve_payment_method)
      end
    end
  end
end
