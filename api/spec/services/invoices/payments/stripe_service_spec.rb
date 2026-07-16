# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::StripeService do
  subject(:stripe_service) { described_class.new(invoice) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:stripe_payment_provider) { create(:stripe_provider, organization:, code:) }
  let(:stripe_customer) { create(:stripe_customer, customer:, payment_method_id: "pm_123456") }
  let(:code) { "stripe_1" }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 200,
      total_paid_amount_cents:,
      currency: "EUR",
      ready_for_payment_processing: true
    )
  end

  let(:total_paid_amount_cents) { 0 }

  describe "#generate_payment_url" do
    let(:payment_intent) { create(:payment_intent) }

    before do
      stripe_payment_provider
      stripe_customer

      allow(::Stripe::Checkout::Session).to receive(:create)
        .and_return({"url" => "https://example.com"})
    end

    it "generates payment url" do
      stripe_service.generate_payment_url(payment_intent)

      expect(::Stripe::Checkout::Session).to have_received(:create)
    end

    it "captures the checkout session id on the result" do
      allow(::Stripe::Checkout::Session).to receive(:create)
        .and_return({"url" => "https://example.com", "id" => "cs_123"})

      result = stripe_service.generate_payment_url(payment_intent)

      expect(result.payment_url).to eq("https://example.com")
      expect(result.provider_session_id).to eq("cs_123")
    end

    describe "#payment_url_payload" do
      let(:payment_url_payload) { stripe_service.__send__(:payment_url_payload, payment_intent) }

      let(:payload) do
        {
          line_items: [
            {
              quantity: 1,
              price_data: {
                currency: invoice.currency.downcase,
                unit_amount: invoice.total_due_amount_cents,
                product_data: {
                  name: invoice.number
                }
              }
            }
          ],
          mode: "payment",
          success_url: stripe_service.__send__(:success_redirect_url),
          customer: customer.stripe_customer.provider_customer_id,
          payment_method_types: customer.stripe_customer.provider_payment_methods,
          expires_at: payment_intent.expires_at.to_i,
          payment_intent_data: {
            description: stripe_service.__send__(:description),
            setup_future_usage: "off_session",
            metadata: {
              lago_customer_id: customer.id,
              lago_invoice_id: invoice.id,
              invoice_issuing_date: invoice.issuing_date.iso8601,
              invoice_type: invoice.invoice_type,
              payment_type: "one-time"
            }
          }
        }
      end

      context "when paid amount is not zero" do
        let(:total_paid_amount_cents) { 1 }

        it "return the payload" do
          expect(payment_url_payload).to eq(payload)
        end
      end

      context "when paid amount is zero" do
        it "returns the payload" do
          expect(payment_url_payload).to eq(payload)
        end
      end

      context "when customer is from India" do
        let(:customer) { create(:customer, payment_provider_code: code, country: "IN") }

        it "does not save the card" do
          expect(payment_url_payload[:payment_intent_data][:setup_future_usage]).to be_nil
        end
      end

      context "when customer can use crypto" do
        it "does not save the card" do
          stripe_customer.provider_payment_methods << "crypto"
          stripe_customer.save!
          expect(payment_url_payload[:payment_intent_data][:setup_future_usage]).to be_nil
        end
      end
    end

    context "with an error on Stripe" do
      before do
        allow(::Stripe::Checkout::Session).to receive(:create)
          .and_raise(::Stripe::InvalidRequestError.new("error", {}))
      end

      it "returns a failed result" do
        result = stripe_service.generate_payment_url(payment_intent)

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::ThirdPartyFailure)
        expect(result.error.third_party).to eq("Stripe")
        expect(result.error.error_message).to eq("error")
      end
    end
  end

  describe "#expire_payment_url" do
    let(:payment_intent) { create(:payment_intent, invoice:, provider_session_id:) }
    let(:provider_session_id) { "cs_123" }
    let(:session_status) { "open" }
    let(:stripe_session) { ::Stripe::Checkout::Session.construct_from(status: session_status) }

    before do
      stripe_payment_provider
      stripe_customer

      allow(::Stripe::Checkout::Session).to receive(:retrieve).and_return(stripe_session)
      allow(::Stripe::Checkout::Session).to receive(:expire)
    end

    it "expires the open checkout session" do
      stripe_service.expire_payment_url(payment_intent)

      expect(::Stripe::Checkout::Session).to have_received(:expire)
        .with(provider_session_id, {}, {api_key: stripe_payment_provider.secret_key})
    end

    context "when the session is no longer open" do
      let(:session_status) { "complete" }

      it "does not expire the session" do
        stripe_service.expire_payment_url(payment_intent)

        expect(::Stripe::Checkout::Session).not_to have_received(:expire)
      end
    end

    context "when the session can no longer be expired" do
      before do
        allow(::Stripe::Checkout::Session).to receive(:expire)
          .and_raise(::Stripe::InvalidRequestError.new("not open", {}))
      end

      it "treats it as a no-op success" do
        result = stripe_service.expire_payment_url(payment_intent)

        expect(result).to be_success
      end
    end

    context "when the payment intent has no provider session id" do
      let(:provider_session_id) { nil }

      it "does nothing and returns success" do
        result = stripe_service.expire_payment_url(payment_intent)

        expect(result).to be_success
        expect(::Stripe::Checkout::Session).not_to have_received(:retrieve)
        expect(::Stripe::Checkout::Session).not_to have_received(:expire)
      end
    end
  end

  describe "#update_payment_status" do
    let(:payment) do
      create(
        :payment,
        payable: invoice,
        provider_payment_id: "ch_123456"
      )
    end

    let(:stripe_payment) do
      PaymentProviders::StripeProvider::StripePayment.new(
        id: "ch_123456",
        status: "succeeded",
        metadata: {},
        error_code: nil
      )
    end

    before do
      allow(SegmentTrackJob).to receive(:perform_later)
      payment
    end

    it "updates the payment and invoice status" do
      result = stripe_service.update_payment_status(
        organization_id: organization.id,
        status: "succeeded",
        stripe_payment:
      )

      expect(result).to be_success
      expect(result.payment.status).to eq("succeeded")
      expect(result.payment.payable_payment_status).to eq("succeeded")
      expect(result.invoice.reload).to have_attributes(
        payment_status: "succeeded",
        ready_for_payment_processing: false,
        total_paid_amount_cents: invoice.total_amount_cents
      )
    end

    it "enqueues a SendWebhookJob for payment.succeeded" do
      expect do
        stripe_service.update_payment_status(
          organization_id: organization.id,
          status: "succeeded",
          stripe_payment:
        )
      end.to have_enqueued_job(SendWebhookJob).with("payment.succeeded", Payment)
    end

    context "when status is failed" do
      let(:stripe_payment) do
        PaymentProviders::StripeProvider::StripePayment.new(
          id: "ch_123456",
          status: "canceled",
          metadata: {},
          error_code: nil
        )
      end

      it "updates the payment and invoice status" do
        result = stripe_service.update_payment_status(
          organization_id: organization.id,
          status: "failed",
          stripe_payment:
        )

        expect(result).to be_success
        expect(result.payment.status).to eq("failed")
        expect(result.payment.payable_payment_status).to eq("failed")
        expect(result.invoice.reload).to have_attributes(
          payment_status: "failed",
          ready_for_payment_processing: true
        )
      end

      context "when there is another payment in requires_action state for the invoice" do
        it "updates the payment status but not the invoice status" do
          # We can only have one `pending/processing` payment for an invoice
          # in this case, we're testing a webhook arriving later when the retry with 3ds support has already started
          # This can only happen if the first payment, was already failed.
          payment.update!(payable_payment_status: "failed")
          old_value = payment.payable.ready_for_payment_processing
          create(:payment, payable: invoice, status: "requires_action")

          result = stripe_service.update_payment_status(
            organization_id: organization.id,
            status: "failed",
            stripe_payment:
          )

          expect(result).to be_success
          expect(result.payment.status).to eq("failed")
          expect(result.payment.payable_payment_status).to eq("failed")

          expect(result.invoice.reload).to have_attributes(
            payment_status: "pending",
            ready_for_payment_processing: old_value
          )
        end
      end
    end

    context "when invoice is already payment_succeeded" do
      before { invoice.payment_succeeded! }

      it "does not update the status of invoice and payment" do
        result = stripe_service.update_payment_status(
          organization_id: organization.id,
          status: "succeeded",
          stripe_payment:
        )

        expect(result).to be_success
        expect(result.invoice.payment_status).to eq("succeeded")
      end
    end

    context "with invalid status" do
      it "does not update the status of invoice and payment" do
        result = stripe_service.update_payment_status(
          organization_id: organization.id,
          status: "foo-bar",
          stripe_payment:
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:payable_payment_status)
        expect(result.error.messages[:payable_payment_status]).to include("value_is_invalid")
      end
    end

    context "when payment is not found and it is one time payment" do
      let(:payment) { nil }

      let(:stripe_payment) do
        PaymentProviders::StripeProvider::StripePayment.new(
          id: "ch_123456",
          status: "succeeded",
          metadata: {lago_invoice_id: invoice.id, payment_type: "one-time"},
          error_code: nil
        )
      end

      before do
        stripe_payment_provider
        stripe_customer
      end

      it "creates a payment and updates invoice payment status" do
        result = stripe_service.update_payment_status(
          organization_id: organization.id,
          status: "succeeded",
          stripe_payment:
        )

        expect(result).to be_success
        expect(result.payment.organization).to eq(organization)
        expect(result.payment.status).to eq("succeeded")
        expect(result.payment.payable_payment_status).to eq("succeeded")
        expect(result.invoice.reload).to have_attributes(
          payment_status: "succeeded",
          ready_for_payment_processing: false
        )
      end

      context "when amount_cents kwarg is provided" do
        it "records the Payment with the provider-reported amount, not the invoice due amount" do
          result = stripe_service.update_payment_status(
            organization_id: organization.id,
            status: "succeeded",
            amount_cents: 4242,
            stripe_payment:
          )

          expect(result.payment.amount_cents).to eq(4242)
        end
      end

      context "when amount_cents kwarg is not provided" do
        it "falls back to the invoice's total due amount" do
          result = stripe_service.update_payment_status(
            organization_id: organization.id,
            status: "succeeded",
            stripe_payment:
          )

          expect(result.payment.amount_cents).to eq(invoice.total_due_amount_cents)
        end
      end

      context "when invoice is not found" do
        let(:stripe_payment) do
          PaymentProviders::StripeProvider::StripePayment.new(
            id: "ch_123456",
            status: "succeeded",
            metadata: {lago_invoice_id: "invalid", payment_type: "one-time"},
            error_code: nil
          )
        end

        it "raises a not found failure" do
          result = stripe_service.update_payment_status(
            organization_id: organization.id,
            status: "succeeded",
            stripe_payment:
          )

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("invoice_not_found")
        end
      end
    end

    context "when payment is not found" do
      let(:payment) { nil }

      it "returns an empty result" do
        result = stripe_service.update_payment_status(
          organization_id: organization.id,
          status: "succeeded",
          stripe_payment:
        )

        expect(result).to be_success
        expect(result.payment).to be_nil
      end

      context "with invoice id in metadata" do
        let(:stripe_payment) do
          PaymentProviders::StripeProvider::StripePayment.new(
            id: "ch_123456",
            status: "succeeded",
            metadata: {lago_invoice_id: SecureRandom.uuid},
            error_code: nil
          )
        end

        it "returns an empty result" do
          result = stripe_service.update_payment_status(
            organization_id: organization.id,
            status: "succeeded",
            stripe_payment:
          )

          expect(result).to be_success
          expect(result.payment).to be_nil
        end

        context "when the invoice is found for organization" do
          let(:stripe_payment) do
            PaymentProviders::StripeProvider::StripePayment.new(
              id: "ch_123456",
              status: "succeeded",
              metadata: {lago_invoice_id: invoice.id},
              error_code: nil
            )
          end

          before do
            stripe_customer
            stripe_payment_provider
          end

          it "creates the missing payment and updates invoice status" do
            result = stripe_service.update_payment_status(
              organization_id: organization.id,
              status: "succeeded",
              stripe_payment:
            )

            expect(result).to be_success
            expect(result.payment.status).to eq("succeeded")
            expect(result.payment.payable_payment_status).to eq("succeeded")
            expect(result.invoice.reload).to have_attributes(
              payment_status: "succeeded",
              ready_for_payment_processing: false
            )

            expect(invoice.payments.count).to eq(1)
            payment = invoice.payments.first
            expect(payment).to have_attributes(
              payable: invoice,
              payment_provider_id: stripe_payment_provider.id,
              payment_provider_customer_id: stripe_customer.id,
              amount_cents: invoice.total_amount_cents,
              amount_currency: invoice.currency,
              provider_payment_id: "ch_123456",
              status: "succeeded"
            )
          end
        end
      end
    end

    context "when payment's payable belongs to another organization" do
      let(:invoice) { create(:invoice) }

      it "does not update the payment status" do
        result = stripe_service.update_payment_status(
          organization_id: organization.id,
          status: "succeeded",
          stripe_payment:
        )

        expect(result).to be_success
        expect(result.payment).to be_nil
        expect(invoice.reload.payment_status).to eq("pending")
        expect(payment.reload.status).to eq("pending")
      end
    end
  end
end
