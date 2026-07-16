# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::Webhooks::PaymentIntentPaymentFailedService do
  subject(:event_service) { described_class.new(organization_id: organization.id, event:) }

  let(:event) { ::Stripe::Event.construct_from(JSON.parse(event_json)) }
  let(:organization) { create(:organization) }

  ["2020-08-27", "2024-09-30.acacia", "2025-04-30.basil"].each do |version|
    context "when payment intent event" do
      let(:event_json) { get_stripe_fixtures("webhooks/payment_intent_payment_failed.json", version:) }

      it "updates the payment status and save the payment method" do
        expect_any_instance_of(Invoices::Payments::StripeService).to receive(:update_payment_status) # rubocop:disable RSpec/AnyInstance
          .with(
            organization_id: organization.id,
            status: "failed",
            amount_cents: anything,
            stripe_payment: PaymentProviders::StripeProvider::StripePayment
          ).and_call_original

        invoice = create(:invoice, organization:)
        payment = create(:payment, payable: invoice, provider_payment_id: event.data.object.id)

        result = event_service.call

        expect(result).to be_success
        expect(payment.reload.error_code).to eq("authentication_required")
      end
    end

    context "when payment intent is canceled" do
      let(:event_json) { get_stripe_fixtures("webhooks/payment_intent_canceled.json", version:) }

      it "updates the payment status and save the payment method" do
        expect_any_instance_of(Invoices::Payments::StripeService).to receive(:update_payment_status) # rubocop:disable RSpec/AnyInstance
          .with(
            organization_id: organization.id,
            status: "failed",
            amount_cents: anything,
            stripe_payment: PaymentProviders::StripeProvider::StripePayment
          ).and_call_original

        create(:payment, provider_payment_id: event.data.object.id)

        result = event_service.call

        expect(result).to be_success
      end
    end

    context "when payment intent event for a payment request" do
      let(:event_json) do
        get_stripe_fixtures("webhooks/payment_intent_payment_failed.json", version:) do |h|
          h["data"]["object"]["metadata"] = {
            lago_payable_type: "PaymentRequest",
            lago_payment_request_id: "a587e552-36bc-4334-81f2-abcbf034ad3f"
          }
        end
      end

      it "routes the event to an other service" do
        expect_any_instance_of(PaymentRequests::Payments::StripeService).to receive(:update_payment_status) # rubocop:disable RSpec/AnyInstance
          .with(
            organization_id: organization.id,
            status: "failed",
            amount_cents: anything,
            stripe_payment: PaymentProviders::StripeProvider::StripePayment
          ).and_call_original

        payment = create(:payment, provider_payment_id: event.data.object.id)
        create(:payment_request, customer: create(:customer, organization:), payments: [payment])

        result = event_service.call

        expect(result).to be_success
      end
    end

    context "when payment intent event with an invalid payable type" do
      let(:event_json) do
        get_stripe_fixtures("webhooks/payment_intent_payment_failed.json", version:) do |h|
          h["data"]["object"]["metadata"]["lago_payable_type"] = "InvalidPayableTypeName"
        end
      end

      it do
        expect { event_service.call }.to raise_error(NameError, "Invalid lago_payable_type: InvalidPayableTypeName")
      end
    end
  end

  context "when last_payment_error does not have code" do
    let(:event_json) do
      get_stripe_fixtures("webhooks/payment_intent_payment_failed.json", version: "2025-04-30.basil") do |h|
        h["data"]["object"]["last_payment_error"] = {message: "error"}
      end
    end

    it "updates the payment status and save the payment method" do
      expect_any_instance_of(Invoices::Payments::StripeService).to receive(:update_payment_status) # rubocop:disable RSpec/AnyInstance
        .with(
          organization_id: organization.id,
          status: "failed",
          amount_cents: anything,
          stripe_payment: PaymentProviders::StripeProvider::StripePayment
        ).and_call_original

      invoice = create(:invoice, organization:)
      payment = create(:payment, payable: invoice, provider_payment_id: event.data.object.id)

      result = event_service.call

      expect(result).to be_success
      expect(payment.reload.error_code).to be_nil
    end
  end
end
