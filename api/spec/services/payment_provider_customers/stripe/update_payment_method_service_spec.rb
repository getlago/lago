# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviderCustomers::Stripe::UpdatePaymentMethodService do
  subject(:update_service) { described_class.new(stripe_customer:, payment_method_id:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  let(:stripe_customer) { create(:stripe_customer, customer:) }
  let(:payment_method_id) { "pm_123456" }

  describe "#call" do
    it "updates the customer payment method" do
      result = update_service.call

      expect(result).to be_success
      expect(result.stripe_customer.payment_method_id).to eq(payment_method_id)
    end

    context "without payment_method" do
      it "creates a new one with provider_method_id" do
        expect(customer.payment_methods.count).to eq(0)
        result = update_service.call

        expect(result).to be_success
        expect(result.payment_method.provider_method_id).to eq(payment_method_id)
        expect(result.payment_method.is_default).to be_truthy
        expect(customer.payment_methods.count).to eq(1)
      end
    end

    context "with existing payment_method" do
      before do
        create(:payment_method, customer:, payment_provider_customer: stripe_customer, provider_method_id: payment_method_id, is_default: false)
      end

      it "set as default" do
        result = update_service.call

        expect(result).to be_success
        expect(result.payment_method.provider_method_id).to eq(payment_method_id)
        expect(result.payment_method.is_default).to be_truthy
      end
    end

    context "when payment_method_id is nil" do
      let(:payment_method_id) { nil }

      it "does not create a PaymentMethod" do
        expect { update_service.call }.not_to change(PaymentMethod, :count)
      end
    end

    context "with pending invoices" do
      let(:invoice) do
        create(
          :invoice,
          customer:,
          total_amount_cents: 200,
          currency: "EUR",
          status:,
          ready_for_payment_processing:
        )
      end

      let(:status) { "finalized" }
      let(:ready_for_payment_processing) { true }

      before { invoice }

      it "enqueues jobs to reprocess the pending payment" do
        result = update_service.call

        expect(result).to be_success
        expect(Invoices::Payments::CreateJob).to have_been_enqueued
          .with(invoice:, payment_provider: :stripe)
      end

      context "when invoices are not finalized" do
        let(:status) { "draft" }

        it "does not enqueue jobs to reprocess pending payment" do
          result = update_service.call

          expect(result).to be_success
          expect(Invoices::Payments::CreateJob).not_to have_been_enqueued
        end
      end

      context "when invoices are not ready for payment processing" do
        let(:ready_for_payment_processing) { "false" }

        it "does not enqueue jobs to reprocess pending payment" do
          result = update_service.call

          expect(result).to be_success
          expect(Invoices::Payments::CreateJob).not_to have_been_enqueued
        end
      end
    end

    context "when customer is deleted" do
      let(:customer) { create(:customer, organization:, deleted_at: Time.current) }

      it "Fails with deleted_customer error" do
        stripe_customer.reload
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq(:deleted_customer)
        expect(result.error.message).to include("Customer associated to this stripe customer was deleted")
      end
    end
  end
end
