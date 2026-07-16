# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::SetPaymentMethodDataService do
  subject(:service) { described_class.new(payment:, provider_payment_method_id:) }

  let(:provider_payment_method_id) { "pm_1R2DFsQ8iJWBZFaMw3LLbR0r" }
  let(:organization) { create(:organization) }

  describe "#call" do
    context "with Stripe" do
      let(:payment) { create(:payment, payment_provider: create(:stripe_provider), organization:) }

      it "updates the payment method data" do
        stub_request(:get, %r{/v1/payment_methods/pm_}).and_return(
          status: 200, body: get_stripe_fixtures("retrieve_payment_method_response.json")
        )

        result = service.call

        expect(result.payment.provider_payment_method_id).to eq "pm_1R2DFsQ8iJWBZFaMw3LLbR0r"
        expect(result.payment.provider_payment_method_data["type"]).to eq("card")
        expect(result.payment.provider_payment_method_data["brand"]).to eq("visa")
        expect(result.payment.provider_payment_method_data["last4"]).to eq("4242")
        expect(result.payment&.payment_method&.details).to be_nil
      end

      context "when the payment has a payment method" do
        let(:payment_method) { create(:payment_method, organization:) }
        let(:payment) { create(:payment, payment_provider: create(:stripe_provider), organization:, payment_method:) }

        it "updates payment data and the payment method details" do
          stub_request(:get, %r{/v1/payment_methods/pm_}).and_return(
            status: 200, body: get_stripe_fixtures("retrieve_payment_method_response.json")
          )

          result = service.call

          expect(result.payment.provider_payment_method_id).to eq "pm_1R2DFsQ8iJWBZFaMw3LLbR0r"
          expect(result.payment.provider_payment_method_data["type"]).to eq("card")
          expect(result.payment.provider_payment_method_data["brand"]).to eq("visa")
          expect(result.payment.provider_payment_method_data["last4"]).to eq("4242")
          expect(result.payment.payment_method.reload.details["type"]).to eq("card")
          expect(result.payment.payment_method.reload.details["brand"]).to eq("visa")
          expect(result.payment.payment_method.reload.details["last4"]).to eq("4242")
        end
      end

      context "when the payment method id is already set" do
        it "does not call stripe" do
          payment.update!(
            provider_payment_method_id: provider_payment_method_id,
            provider_payment_method_data: {existing: "data"}
          )
          result = service.call
          expect(result.payment.provider_payment_method_id).to eq provider_payment_method_id
          expect(result.payment.provider_payment_method_data).to eq({"existing" => "data"})
        end
      end
    end

    context "with any other provider" do
      let(:payment) { create(:payment, payment_provider: create(:gocardless_provider)) }

      it do
        expect { service.call }.to raise_error(NotImplementedError)
      end
    end
  end
end
