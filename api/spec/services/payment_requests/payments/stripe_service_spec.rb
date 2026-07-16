# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::Payments::StripeService do
  subject(:stripe_service) { described_class.new(payment_request) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:billing_entity) { organization.default_billing_entity }
  let(:stripe_payment_provider) { create(:stripe_provider, organization:, code:) }
  let(:stripe_customer) {
    create(:stripe_customer, customer:, payment_method_id: stripe_payment_method_id)
  }
  let(:stripe_payment_method_id) { "pm_123456" }
  let(:code) { "stripe_1" }

  let(:payment_request) do
    create(
      :payment_request,
      organization:,
      customer:,
      amount_cents: 799,
      amount_currency: "EUR",
      invoices:
    )
  end

  let(:invoices) { [invoice_1, invoice_2] }

  let(:invoice_1) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 200,
      currency: "EUR",
      ready_for_payment_processing: true
    )
  end

  let(:invoice_2) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 599,
      currency: "EUR",
      ready_for_payment_processing: true
    )
  end

  describe "#generate_payment_url" do
    before do
      stripe_payment_provider
      stripe_customer

      allow(::Stripe::Checkout::Session).to receive(:create)
        .and_return({"url" => "https://example.com"})
    end

    it "generates payment url" do
      stripe_service.generate_payment_url

      expect(::Stripe::Checkout::Session)
        .to have_received(:create)
        .with(
          {
            line_items: [
              {
                quantity: 1,
                price_data: {
                  currency: invoice_1.currency.downcase,
                  unit_amount: invoice_1.total_amount_cents,
                  product_data: {name: invoice_1.number}
                }
              },
              {
                quantity: 1,
                price_data: {
                  currency: invoice_2.currency.downcase,
                  unit_amount: invoice_2.total_amount_cents,
                  product_data: {name: invoice_2.number}
                }
              }
            ],
            mode: "payment",
            success_url: stripe_payment_provider.success_redirect_url,
            customer: customer.stripe_customer.provider_customer_id,
            payment_method_types: customer.stripe_customer.provider_payment_methods,
            payment_intent_data: {
              description: "#{billing_entity.name} - Overdue invoices",
              metadata: {
                lago_customer_id: customer.id,
                lago_payable_id: payment_request.id,
                lago_payable_type: "PaymentRequest",
                payment_type: "one-time"
              }
            }
          },
          hash_including({api_key: an_instance_of(String)})
        )
    end

    context "when payment request is related to a single overdue invoice" do
      let(:invoices) { [invoice_1] }

      it "includes the invoice number in stripe data" do
        stripe_service.generate_payment_url

        expect(::Stripe::Checkout::Session)
          .to have_received(:create)
          .with(
            {
              line_items: [
                {
                  quantity: 1,
                  price_data: {
                    currency: invoice_1.currency.downcase,
                    unit_amount: invoice_1.total_amount_cents,
                    product_data: {name: invoice_1.number}
                  }
                }
              ],
              mode: "payment",
              success_url: stripe_payment_provider.success_redirect_url,
              customer: customer.stripe_customer.provider_customer_id,
              payment_method_types: customer.stripe_customer.provider_payment_methods,
              payment_intent_data: {
                description: "#{billing_entity.name} - Overdue invoices: #{invoice_1.number}",
                metadata: {
                  lago_customer_id: customer.id,
                  lago_payable_id: payment_request.id,
                  lago_payable_type: "PaymentRequest",
                  payment_type: "one-time"
                }
              }
            },
            hash_including({api_key: an_instance_of(String)})
          )
      end
    end

    context "with an error on Stripe" do
      before do
        allow(::Stripe::Checkout::Session).to receive(:create)
          .and_raise(::Stripe::InvalidRequestError.new("error", {}))
      end

      it "returns a failed result" do
        result = stripe_service.generate_payment_url

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::ThirdPartyFailure)
        expect(result.error.third_party).to eq("Stripe")
        expect(result.error.error_message).to eq("error")
      end
    end
  end

  describe "#update_payment_status" do
    subject(:result) do
      stripe_service.update_payment_status(
        organization_id: organization.id,
        stripe_payment:,
        status:
      )
    end

    let(:status) { "succeeded" }

    let(:payment) do
      create(
        :payment,
        payable: payment_request,
        provider_payment_id: stripe_payment.id
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
      allow(SendWebhookJob).to receive(:perform_later)
      payment
    end

    it "updates the payment, payment_request and invoice payment_status" do
      expect(result).to be_success
      expect(result.payment.status).to eq(status)
      expect(result.payment.payable_payment_status).to eq("succeeded")

      expect(result.payable.reload).to be_payment_succeeded
      expect(result.payable.ready_for_payment_processing).to eq(false)

      expect(invoice_1.reload).to be_payment_succeeded
      expect(invoice_1.ready_for_payment_processing).to eq(false)
      expect(invoice_2.reload).to be_payment_succeeded
      expect(invoice_2.ready_for_payment_processing).to eq(false)

      expect(invoice_1.total_paid_amount_cents).to eq(invoice_1.total_amount_cents)
      expect(invoice_2.total_paid_amount_cents).to eq(invoice_2.total_amount_cents)
    end

    it "does not send payment requested email" do
      expect { result }.not_to have_enqueued_mail(PaymentRequestMailer, :requested)
    end

    context "when the payment request belongs to a dunning campaign" do
      let(:customer) do
        create(
          :customer,
          payment_provider_code: code,
          last_dunning_campaign_attempt: 3,
          last_dunning_campaign_attempt_at: Time.zone.now
        )
      end

      let(:payment_request) do
        create(
          :payment_request,
          organization:,
          customer:,
          amount_cents: 799,
          amount_currency: "USD",
          invoices: [invoice_1, invoice_2],
          dunning_campaign: create(:dunning_campaign)
        )
      end

      it "resets the customer dunning campaign counters for the payment request currency" do
        expect { result && customer.reload }
          .to change(customer, :last_dunning_campaign_attempt).to(0)
          .and change(customer, :last_dunning_campaign_attempt_at).to(nil)
          .and change(customer, :dunning_currency_attempts).to({"USD" => 0})

        expect(result).to be_success
      end

      context "when status is failed" do
        let(:status) { "failed" }

        it "doest not reset the customer dunning campaign counters" do
          expect { result && customer.reload }
            .to not_change(customer, :last_dunning_campaign_attempt)
            .and not_change { customer.last_dunning_campaign_attempt_at&.to_i }

          expect(result).to be_success
        end
      end
    end

    context "when status is failed" do
      let(:status) { "failed" }

      it "updates the payment, payment_request and invoice status" do
        expect(result).to be_success
        expect(result.payment.status).to eq(status)
        expect(result.payment.payable_payment_status).to eq("failed")

        expect(result.payable.reload).to be_payment_failed
        expect(result.payable.ready_for_payment_processing).to eq(true)

        expect(invoice_1.reload).to be_payment_failed
        expect(invoice_1.ready_for_payment_processing).to eq(true)

        expect(invoice_2.reload).to be_payment_failed
        expect(invoice_2.ready_for_payment_processing).to eq(true)

        expect(invoice_1.total_paid_amount_cents).to eq(0)
        expect(invoice_2.total_paid_amount_cents).to eq(0)
      end

      it "sends a payment requested email" do
        expect { result }.to have_enqueued_mail(PaymentRequestMailer, :requested)
          .with(params: {payment_request:}, args: [])
      end
    end

    context "when invoices have offset amounts from credit notes" do
      let(:credit_note_1) do
        create(
          :credit_note,
          invoice: invoice_1,
          customer:,
          offset_amount_cents: 50,
          credit_amount_cents: 0,
          refund_amount_cents: 0,
          total_amount_cents: 50,
          status: :finalized
        )
      end

      let(:credit_note_2) do
        create(
          :credit_note,
          invoice: invoice_2,
          customer:,
          offset_amount_cents: 99,
          credit_amount_cents: 0,
          refund_amount_cents: 0,
          total_amount_cents: 99,
          status: :finalized
        )
      end

      before do
        credit_note_1
        credit_note_2
      end

      it "updates invoices considering offset amounts" do
        expect(result).to be_success

        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_2.reload).to be_payment_succeeded

        # Invoice 1: total_amount_cents = 200, offset = 50, due = 150
        # After payment: total_paid_amount_cents should be 150 (to cover the due amount)
        expect(invoice_1.total_paid_amount_cents).to eq(150)

        # Invoice 2: total_amount_cents = 599, offset = 99, due = 500
        # After payment: total_paid_amount_cents should be 500 (to cover the due amount)
        expect(invoice_2.total_paid_amount_cents).to eq(500)
      end

      it "marks invoices as paid even though paid amount doesn't equal total amount" do
        result

        # Due to offsets, paid amount < total amount, but invoice should still be marked as paid
        expect(invoice_1.reload.total_paid_amount_cents).to be < invoice_1.total_amount_cents
        expect(invoice_2.reload.total_paid_amount_cents).to be < invoice_2.total_amount_cents

        expect(invoice_1).to be_payment_succeeded
        expect(invoice_2).to be_payment_succeeded
      end
    end

    context "when invoice is fully offset by credit note" do
      let(:invoice_3) do
        create(
          :invoice,
          organization:,
          customer:,
          total_amount_cents: 100,
          currency: "EUR",
          ready_for_payment_processing: true
        )
      end

      let(:credit_note_3) do
        create(
          :credit_note,
          invoice: invoice_3,
          customer:,
          offset_amount_cents: 100,
          credit_amount_cents: 0,
          refund_amount_cents: 0,
          total_amount_cents: 100,
          status: :finalized
        )
      end

      let(:invoices) { [invoice_1, invoice_2, invoice_3] }

      before { credit_note_3 }

      it "does not increase paid amount for fully offset invoice" do
        result

        # Invoice 3 is fully offset, so total_due_amount_cents = 0
        # No payment should be applied to it
        expect(invoice_3.reload.total_paid_amount_cents).to eq(0)
        expect(invoice_3).to be_payment_succeeded
      end
    end

    context "when invoice is partially paid and has offset amount" do
      let(:invoice_1) do
        create(
          :invoice,
          organization:,
          customer:,
          total_amount_cents: 300,
          total_paid_amount_cents: 100,
          currency: "EUR",
          ready_for_payment_processing: true
        )
      end

      let(:credit_note) do
        create(
          :credit_note,
          invoice: invoice_1,
          customer:,
          offset_amount_cents: 50,
          credit_amount_cents: 0,
          refund_amount_cents: 0,
          total_amount_cents: 50,
          status: :finalized
        )
      end

      before { credit_note }

      it "updates paid amount correctly" do
        result

        # Invoice 1: total = 300, already paid = 100, offset = 50, due = 150
        # After payment: total_paid_amount_cents = 100 + 150 = 250
        expect(invoice_1.reload.total_paid_amount_cents).to eq(250)
        expect(invoice_1).to be_payment_succeeded
      end
    end

    context "when payment_request and invoice is already payment_succeeded" do
      before do
        payment_request.payment_succeeded!
        invoice_1.payment_succeeded!
        invoice_2.payment_succeeded!
      end

      it "does not update the status of invoice, payment_request and payment" do
        expect { result }
          .to not_change { invoice_1.reload.payment_status }
          .and not_change { invoice_2.reload.payment_status }
          .and not_change { payment_request.reload.payment_status }
          .and not_change { payment.reload.status }

        expect(result).to be_success
      end

      it "does not send payment requested email" do
        expect { result }.not_to have_enqueued_mail(PaymentRequestMailer, :requested)
      end
    end

    context "when a failed webhook arrives after the invoice was already paid through another path" do
      let(:status) { "failed" }

      before do
        payment_request.payment_failed!
        invoice_1.payment_succeeded!
        invoice_2.payment_succeeded!
      end

      it "leaves already-succeeded invoices untouched" do
        expect { result }
          .to not_change { invoice_1.reload.payment_status }
          .and not_change { invoice_2.reload.payment_status }

        expect(result).to be_success
        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_2.reload).to be_payment_succeeded
      end
    end

    context "with invalid status" do
      let(:status) { "invalid-status" }

      it "does not update the payment_status of payment_request, invoice and payment" do
        expect { result }
          .to not_change { payment_request.reload.payment_status }
          .and not_change { invoice_1.reload.payment_status }
          .and not_change { invoice_2.reload.payment_status }
          .and not_change { payment.reload.status }
      end

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:payable_payment_status)
        expect(result.error.messages[:payable_payment_status]).to include("value_is_invalid")
      end

      it "does not send payment requested email" do
        expect { result }.not_to have_enqueued_mail(PaymentRequestMailer, :requested)
      end
    end

    context "when payment is not found and it is one time payment" do
      let(:payment) { nil }
      let(:status) { "succeeded" }

      let(:stripe_payment) do
        PaymentProviders::StripeProvider::StripePayment.new(
          id: "ch_123456",
          status: "succeeded",
          metadata: {
            lago_payable_id: payment_request.id,
            lago_payable_type: "PaymentRequest",
            payment_type: "one-time"
          },
          error_code: nil
        )
      end

      before do
        stripe_payment_provider
        stripe_customer
      end

      it "creates a payment and updates payment request and invoice payment status" do
        expect(result).to be_success
        expect(result.payment.status).to eq(status)
        expect(result.payment.payable_payment_status).to eq("succeeded")

        expect(result.payable.reload).to be_payment_succeeded
        expect(result.payable.ready_for_payment_processing).to eq(false)

        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_1.ready_for_payment_processing).to eq(false)
        expect(invoice_2.reload).to be_payment_succeeded
        expect(invoice_2.ready_for_payment_processing).to eq(false)
      end

      context "when payment request is not found" do
        let(:stripe_payment) do
          PaymentProviders::StripeProvider::StripePayment.new(
            id: "ch_123456",
            status: "succeeded",
            metadata: {
              lago_payable_id: "invalid",
              lago_payable_type: "PaymentRequest",
              payment_type: "one-time"
            },
            error_code: nil
          )
        end

        it "raises a not found failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("payment_request_not_found")
        end
      end
    end

    context "when the payment is found by stripe payment id" do
      let(:payment) do
        create(
          :payment,
          payable: payment_request,
          provider_payment_id: stripe_payment.id,
          status: "pending"
        )
      end

      let(:stripe_payment) do
        PaymentProviders::StripeProvider::StripePayment.new(
          id: "ch_123456",
          status: "succeeded",
          metadata: {
            lago_payable_id: payment_request.id,
            lago_payable_type: "PaymentRequest",
            payment_type: "one-time"
          },
          error_code: nil
        )
      end

      before do
        stripe_payment_provider
        stripe_customer
        payment
      end

      it "updates the payment status and related entities" do
        expect(result).to be_success
        expect(result.payment.status).to eq("succeeded")
        expect(result.payment.payable_payment_status).to eq("succeeded")

        expect(result.payable.reload).to be_payment_succeeded
        expect(result.payable.ready_for_payment_processing).to eq(false)

        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_1.ready_for_payment_processing).to eq(false)
        expect(invoice_2.reload).to be_payment_succeeded
        expect(invoice_2.ready_for_payment_processing).to eq(false)

        expect(invoice_1.total_paid_amount_cents).to eq(invoice_1.total_amount_cents)
        expect(invoice_2.total_paid_amount_cents).to eq(invoice_2.total_amount_cents)
      end

      it "does not create a new payment" do
        expect { result }.not_to change(Payment, :count)
      end
    end

    context "when payment is not found" do
      let(:payment) { nil }
      let(:status) { "succeeded" }

      it "returns an empty result" do
        expect(result).to be_success
        expect(result.payment).to be_nil
      end

      context "with payment request id in metadata" do
        let(:stripe_payment) do
          PaymentProviders::StripeProvider::StripePayment.new(
            id: "ch_123456",
            status: "succeeded",
            metadata: {
              lago_payable_id: SecureRandom.uuid,
              lago_payable_type: "PaymentRequest"
            },
            error_code: nil
          )
        end

        it "returns an empty result" do
          expect(result).to be_success
          expect(result.payment).to be_nil
        end

        context "when the payment request is found for organization" do
          let(:stripe_payment) do
            PaymentProviders::StripeProvider::StripePayment.new(
              id: "ch_123456",
              status: "succeeded",
              metadata: {
                lago_payable_id: payment_request.id,
                lago_payable_type: "PaymentRequest"
              },
              error_code: nil
            )
          end

          before do
            stripe_customer
            stripe_payment_provider
          end

          it "creates the missing payment and updates payment_request status" do
            expect(result).to be_success
            expect(result.payment.status).to eq(status)
            expect(result.payment.payable_payment_status).to eq("succeeded")

            expect(result.payable.reload).to be_payment_succeeded
            expect(result.payable.ready_for_payment_processing).to eq(false)

            expect(invoice_1.reload).to be_payment_succeeded
            expect(invoice_1.ready_for_payment_processing).to eq(false)
            expect(invoice_2.reload).to be_payment_succeeded
            expect(invoice_2.ready_for_payment_processing).to eq(false)

            expect(payment_request.payments.count).to eq(1)
            payment = payment_request.payments.first
            expect(payment).to have_attributes(
              payable: payment_request,
              payment_provider_id: stripe_payment_provider.id,
              payment_provider_customer_id: stripe_customer.id,
              amount_cents: payment_request.total_amount_cents,
              amount_currency: payment_request.currency,
              provider_payment_id: "ch_123456",
              status: "succeeded"
            )
          end

          context "when a concurrent writer has already persisted the payment" do
            let(:payment) do
              create(
                :payment,
                payable: payment_request,
                provider_payment_id: stripe_payment.id,
                payment_provider: stripe_payment_provider,
                payment_provider_customer: stripe_customer
              )
            end

            before do
              payment
              # Force the initial lookup to miss so the service falls through to handle_missing_payment.
              # The rescue's re-fetch then finds the row the winning writer (a parallel webhook worker
              # or PaymentProviders::Stripe::Payments::CreateService) committed in the meantime.
              allow(Payment).to receive(:find_by)
                .with(provider_payment_id: stripe_payment.id)
                .and_return(nil, payment)
            end

            it "returns a success result with the persisted payment" do
              expect(result).to be_success
              expect(result.payment).to eq(payment)
              expect(result.payable).to eq(payment_request)
            end
          end
        end
      end
    end

    context "when payment belongs to a payment_request from another company" do
      let(:payment_request_other_organization) do
        create(:payment_request, organization: create(:organization))
      end

      let(:payment) do
        create(:payment, payable: payment_request_other_organization, provider_payment_id: "ch_123456")
      end

      it "returns an empty result" do
        expect(result).to be_success
        expect(result.payment).to be_nil
      end

      it "does not update the payment_status of payment_request, invoice and payment" do
        expect { result }
          .to not_change { payment_request.reload.payment_status }
          .and not_change { invoice_1.reload.payment_status }
          .and not_change { invoice_2.reload.payment_status }
          .and not_change { payment.reload.status }
      end
    end

    context "when payment's payable already has a successful payment" do
      let(:payment) { nil }

      let(:stripe_payment) do
        PaymentProviders::StripeProvider::StripePayment.new(
          id: "ch_123456",
          status: "succeeded",
          metadata: {
            lago_payable_id: payment_request.id,
            lago_payable_type: "PaymentRequest"
          },
          error_code: nil
        )
      end

      before do
        stripe_customer
        stripe_payment_provider

        payment_request.payment_succeeded!
      end

      it "returns an empty result" do
        expect(result).to be_success
        expect(result.payment).to be_nil
        expect(result.payable).to be_nil
      end
    end
  end
end
