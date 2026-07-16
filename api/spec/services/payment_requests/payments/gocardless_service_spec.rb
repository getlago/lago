# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::Payments::GocardlessService do
  subject(:gocardless_service) { described_class.new(payment_request) }

  let(:organization) { create(:organization, webhook_url: "https://webhook.com") }
  let(:customer) { create(:customer, organization:, payment_provider_code: code) }
  let(:gocardless_payment_provider) { create(:gocardless_provider, organization:, code:) }
  let(:gocardless_customer) { create(:gocardless_customer, customer:) }
  let(:gocardless_client) { instance_double(GoCardlessPro::Client) }
  let(:gocardless_payments_service) { instance_double(GoCardlessPro::Services::PaymentsService) }
  let(:gocardless_mandates_service) { instance_double(GoCardlessPro::Services::MandatesService) }
  let(:gocardless_list_response) { instance_double(GoCardlessPro::ListResponse) }
  let(:code) { "gocardless_1" }

  let(:payment_request) do
    create(
      :payment_request,
      organization:,
      customer:,
      amount_cents: 799,
      amount_currency: "USD",
      invoices: [invoice_1, invoice_2]
    )
  end

  let(:invoice_1) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 200,
      currency: "USD",
      ready_for_payment_processing: true
    )
  end

  let(:invoice_2) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 599,
      currency: "USD",
      ready_for_payment_processing: true
    )
  end

  describe "#update_payment_status" do
    subject(:result) do
      gocardless_service.update_payment_status(provider_payment_id:, status:)
    end

    let(:status) { "paid_out" }

    let(:payment) do
      create(
        :payment,
        :gocardless_payment,
        payable: payment_request,
        provider_payment_id: provider_payment_id,
        status: "pending_submission"
      )
    end

    let(:provider_payment_id) { "ch_123456" }

    before do
      allow(SegmentTrackJob).to receive(:perform_later)
      allow(SendWebhookJob).to receive(:perform_later)
      payment
    end

    it "updates the payment, payment_request and invoice payment_status" do
      expect(result).to be_success
      expect(result.payment.status).to eq("paid_out")
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
      end

      it "sends a payment requested email" do
        expect { result }.to have_enqueued_mail(PaymentRequestMailer, :requested)
          .with(params: {payment_request:}, args: [])
      end
    end

    context "when payment is not found" do
      let(:payment) { nil }
      let(:status) { "paid_out" }

      it "returns a not found error" do
        expect(result).not_to be_success
        expect(result.payment).to be_nil
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("gocardless_payment_not_found")
      end
    end

    context "when payment_request and invoice is already payment_succeeded" do
      let(:status) { "paid_out" }

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

    context "when payment request is not passed to constructor" do
      let(:gocardless_service) { described_class.new(nil) }
      let(:status) { "paid_out" }

      before do
        payment_request
      end

      it "updates the payment and invoice payment_status" do
        expect(result).to be_success
        expect(result.payment.status).to eq(status)
        expect(result.payment.payable_payment_status).to eq("succeeded")

        expect(result.payable).to be_payment_succeeded
        expect(result.payable.ready_for_payment_processing).to eq(false)

        expect(invoice_1.reload).to be_payment_succeeded
        expect(invoice_1.ready_for_payment_processing).to eq(false)

        expect(invoice_2.reload).to be_payment_succeeded
        expect(invoice_2.ready_for_payment_processing).to eq(false)

        expect(invoice_1.total_paid_amount_cents).to eq(0)
        expect(invoice_2.total_paid_amount_cents).to eq(0)
      end
    end
  end
end
