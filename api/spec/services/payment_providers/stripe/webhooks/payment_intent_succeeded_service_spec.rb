# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Stripe::Webhooks::PaymentIntentSucceededService do
  subject(:event_service) { described_class.new(organization_id: organization.id, event:) }

  let(:event) { ::Stripe::Event.construct_from(JSON.parse(event_json)) }
  let(:organization) { create(:organization) }

  before do
    allow(::Payments::SetPaymentMethodAndCreateReceiptJob).to receive(:perform_later)
      .and_invoke(->(args) { ::Payments::SetPaymentMethodAndCreateReceiptJob.perform_now(**args) })
  end

  ["2020-08-27", "2024-09-30.acacia", "2025-04-30.basil"].each do |version|
    context "when payment intent event (api_version: #{version})" do
      let(:invoice) { create(:invoice, organization:) }
      let(:event_json) { get_stripe_fixtures("webhooks/payment_intent_succeeded.json", version:) }

      before do
        stub_request(:get, %r{/v1/payment_methods/pm_}).and_return(
          status: 200, body: get_stripe_fixtures("retrieve_payment_method_response.json", version:)
        )
      end

      it "updates the payment status and save the payment method" do
        expect_any_instance_of(Invoices::Payments::StripeService).to receive(:update_payment_status) # rubocop:disable RSpec/AnyInstance
          .with(
            organization_id: organization.id,
            status: "succeeded",
            amount_cents: anything,
            stripe_payment: PaymentProviders::StripeProvider::StripePayment
          ).and_call_original

        payment = create(:payment, provider_payment_id: event.data.object.id, payable: invoice)

        result = event_service.call

        expect(result).to be_success
        expect(payment.reload.provider_payment_method_id).to start_with "pm_"
        expect(payment.provider_payment_method_data["type"]).to eq("card")
        expect(payment.provider_payment_method_data["brand"]).to eq("visa")
        expect(payment.provider_payment_method_data["last4"]).to eq("4242")
      end

      it "does not enqueue a payment receipt job" do
        customer = create(:customer, organization:)
        payable = create(:invoice, customer:, issuing_date: "2025-03-17", organization:)
        create(:payment, payable:, provider_payment_id: event.data.object.id)

        expect { event_service.call }.not_to have_enqueued_job(PaymentReceipts::CreateJob)
      end

      context "when issue_receipts_enabled is true", :premium do
        before { organization.update!(premium_integrations: %w[issue_receipts]) }

        it "enqueues a payment receipt job" do
          customer = create(:customer, organization:)
          payable = create(:invoice, customer:, issuing_date: "2025-03-17", organization:)
          create(:payment, payable:, provider_payment_id: event.data.object.id)

          expect { event_service.call }.to have_enqueued_job(PaymentReceipts::CreateJob)
        end
      end
    end

    context "when payment intent event for a payment request" do
      let(:event_json) do
        get_stripe_fixtures("webhooks/payment_intent_succeeded.json", version:) do |h|
          h["data"]["object"]["id"] = "pi_12345"
          h["data"]["object"]["metadata"] = {
            lago_payment_request_id: "a587e552-36bc-4334-81f2-abcbf034ad3f",
            lago_payable_type: "PaymentRequest"
          }
        end
      end

      context "when issue_receipts_enabled is true", :premium do
        before { organization.update!(premium_integrations: %w[issue_receipts]) }

        it "enqueues a payment receipt job" do
          expect_any_instance_of(PaymentRequests::Payments::StripeService).to receive(:update_payment_status) # rubocop:disable RSpec/AnyInstance
            .with(
              organization_id: organization.id,
              status: "succeeded",
              amount_cents: anything,
              stripe_payment: PaymentProviders::StripeProvider::StripePayment.new(
                id: "pi_12345",
                status: "succeeded",
                metadata: {
                  lago_payment_request_id: "a587e552-36bc-4334-81f2-abcbf034ad3f",
                  lago_payable_type: "PaymentRequest"
                },
                error_code: nil
              )
            ).and_call_original

          customer = create(:customer, organization:)
          payment = create(:payment, provider_payment_id: event.data.object.id, customer:)
          create(:payment_request, customer:, payments: [payment])

          stub_request(:get, %r{/v1/payment_methods/pm_}).and_return(
            status: 200, body: get_stripe_fixtures("retrieve_payment_method_response.json", version:)
          )

          expect { event_service.call }.to have_enqueued_job(PaymentReceipts::CreateJob)
        end
      end

      it "routes the event to an other service" do
        expect_any_instance_of(PaymentRequests::Payments::StripeService).to receive(:update_payment_status) # rubocop:disable RSpec/AnyInstance
          .with(
            organization_id: organization.id,
            status: "succeeded",
            amount_cents: anything,
            stripe_payment: PaymentProviders::StripeProvider::StripePayment.new(
              id: "pi_12345",
              status: "succeeded",
              metadata: {
                lago_payment_request_id: "a587e552-36bc-4334-81f2-abcbf034ad3f",
                lago_payable_type: "PaymentRequest"
              },
              error_code: nil
            )
          ).and_call_original

        payment = create(:payment, provider_payment_id: event.data.object.id)
        create(:payment_request, customer: create(:customer, organization:), payments: [payment])

        stub_request(:get, %r{/v1/payment_methods/pm_}).and_return(
          status: 200, body: get_stripe_fixtures("retrieve_payment_method_response.json", version:)
        )

        result = event_service.call

        expect(result).to be_success
        expect(payment.reload.provider_payment_method_id).to start_with "pm_"
        expect(payment.reload.provider_payment_method_data["type"]).to eq("card")
        expect(payment.reload.provider_payment_method_data["brand"]).to eq("visa")
        expect(payment.reload.provider_payment_method_data["last4"]).to eq("4242")
      end

      context "when payment belongs to a payment_request from another organization" do
        let(:payment_request_other_organization) do
          create(:payment_request, organization: create(:organization))
        end

        let(:payment) do
          create(:payment, payable: payment_request_other_organization, provider_payment_id: event.data.object.id)
        end

        it "returns an empty result" do
          result = event_service.call
          expect(result).to be_success
          expect(result.payment).to be_nil
        end

        it "does not update the payment_status of the payment" do
          expect { event_service.call }
            .to not_change { payment.reload.status }
        end

        it "does not enqueue a payment receipt job" do
          expect { event_service.call }.not_to have_enqueued_job(Payments::SetPaymentMethodAndCreateReceiptJob)
        end
      end
    end

    context "when payment intent event with an invalid payable type" do
      let(:event_json) do
        get_stripe_fixtures("webhooks/payment_intent_succeeded.json", version:) do |h|
          h["data"]["object"]["id"] = "pi_12345"
          h["data"]["object"]["metadata"] = {
            lago_payable_type: "InvalidPayableTypeName"
          }
        end
      end

      it do
        expect { event_service.call }.to raise_error(NameError, "Invalid lago_payable_type: InvalidPayableTypeName")
      end
    end
  end
end
