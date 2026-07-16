# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::UpdateCurrencyService do
  subject(:currency_service) { described_class.new(customer:, currency:, customer_update:) }

  let(:customer) { create(:customer, currency: nil) }
  let(:currency) { "USD" }
  let(:customer_update) { false }

  describe "#call" do
    it "assigns the currency to the customer" do
      result = currency_service.call

      expect(result).to be_success
      expect(customer.reload.currency).to eq(currency)
    end

    context "when customer is not found" do
      let(:customer) { nil }

      it "returns a failure" do
        result = currency_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("customer")
      end
    end

    context "when customer currency is the same as the provided one" do
      let(:customer) { create(:customer, currency: "EUR") }
      let(:currency) { customer.currency }

      it "returns a success" do
        expect(currency_service.call).to be_success

        expect(customer.reload.currency).to eq(currency)
      end
    end

    context "when customer already has a currency" do
      let(:customer) { create(:customer, currency: "EUR") }

      it "returns a failure" do
        result = currency_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:currency]).to eq(["currencies_does_not_match"])
      end

      context "when in customer update" do
        let(:customer_update) { true }

        it "assigns the currency to the customer" do
          result = currency_service.call

          expect(result).to be_success
          expect(customer.reload.currency).to eq(currency)
        end

        context "when customer is not editable" do
          before { create(:subscription, customer:) }

          it "returns a failure" do
            result = currency_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages[:currency]).to eq(["currencies_does_not_match"])
          end
        end
      end
    end

    context "when customer is not editable" do
      before { create(:subscription, customer:) }

      it "returns a failure" do
        result = currency_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:currency]).to eq(["currencies_does_not_match"])
      end
    end

    context "when providing an invalid currency" do
      let(:currency) { "INVALID" }

      it "returns a failure" do
        result = currency_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:currency]).to eq(["value_is_invalid"])
      end
    end

    context "when multi_currency flag is enabled" do
      before { customer.organization.enable_feature_flag!(:multi_currency) }

      context "when customer_update is false (billing object creation)" do
        let(:customer_update) { false }

        context "when customer has no currency" do
          let(:customer) { create(:customer, currency: nil) }

          it "sets the currency" do
            result = currency_service.call

            expect(result).to be_success
            expect(customer.reload.currency).to eq(currency)
          end
        end

        context "when customer already has a different currency" do
          let(:customer) { create(:customer, currency: "EUR") }

          it "returns success without updating customer currency" do
            result = currency_service.call

            expect(result).to be_success
            expect(customer.reload.currency).to eq("EUR")
          end
        end
      end

      context "when customer_update is true (direct API update)" do
        let(:customer_update) { true }
        let(:customer) { create(:customer, currency: "EUR") }

        it "allows the currency update" do
          result = currency_service.call

          expect(result).to be_success
          expect(customer.reload.currency).to eq(currency)
        end

        context "when customer has invoices in a different currency" do
          before { create(:invoice, customer:, currency: "EUR", status: :finalized) }

          it "allows the currency update" do
            result = currency_service.call

            expect(result).to be_success
            expect(customer.reload.currency).to eq(currency)
          end
        end

        context "when customer is not editable" do
          before { create(:subscription, customer:) }

          it "allows the currency update" do
            result = currency_service.call

            expect(result).to be_success
            expect(customer.reload.currency).to eq(currency)
          end
        end
      end
    end
  end
end
