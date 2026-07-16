# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethods::CreateFromProviderService do
  subject(:create_service) { described_class.new(customer:, params:, provider_method_id:, payment_provider_id:, payment_provider_customer:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:customer) { create(:customer, organization:) }
  let(:params) {}
  let(:provider_method_id) { "i_cant_be_nil" }
  let(:payment_provider_id) { nil }
  let(:payment_provider_customer) { nil }

  describe "#call" do
    context "without customer" do
      let(:customer) { nil }

      it "fails" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("customer_not_found")
      end
    end

    context "with payment_provider_id" do
      let(:payment_provider_id) { create(:stripe_provider).id }

      it "saves the value" do
        result = create_service.call
        payment_method = result.payment_method

        expect(payment_method).not_to be_nil
        expect(payment_method.payment_provider_id).to eq(payment_provider_id)
      end
    end

    context "with payment_provider_customer" do
      let(:payment_provider_customer) { create(:stripe_customer, customer:, provider_customer_id: "cus_test") }

      it "saves the reference" do
        result = create_service.call
        payment_method = result.payment_method

        expect(payment_method).not_to be_nil
        expect(payment_method.payment_provider_customer).to eq(payment_provider_customer)
      end
    end

    context "with details" do
      subject(:create_service) do
        described_class.new(customer:, params:, provider_method_id:, payment_provider_id:, payment_provider_customer:, details:)
      end

      let(:details) do
        {
          type: "card",
          last4: "4242",
          brand: "visa",
          expiration_month: 12,
          expiration_year: 2028
        }
      end

      it "saves the details" do
        result = create_service.call
        payment_method = result.payment_method

        expect(payment_method).not_to be_nil
        expect(payment_method.details).to eq(
          {
            "type" => "card",
            "last4" => "4242",
            "brand" => "visa",
            "expiration_month" => 12,
            "expiration_year" => 2028
          }
        )
      end
    end

    describe "provider_method_type" do
      context "when included in params" do
        let(:params) do
          {provider_payment_methods: %w[link card sepa_debit]}
        end

        it "saves the first param value" do
          result = create_service.call
          payment_method = result.payment_method

          expect(payment_method.provider_method_type).to eq("link")
        end
      end

      context "when default" do
        let(:params) do
          {}
        end

        it "saves the card value" do
          result = create_service.call
          payment_method = result.payment_method

          expect(payment_method.provider_method_type).to eq("card")
        end
      end
    end
  end
end
