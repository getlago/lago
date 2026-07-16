# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::GocardlessService do
  subject(:gocardless_service) { described_class.new(argument) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:gocardless_payment_provider) { create(:gocardless_provider, organization:, code:) }
  let(:gocardless_customer) { create(:gocardless_customer, customer:) }
  let(:gocardless_client) { instance_double(GoCardlessPro::Client) }
  let(:gocardless_payments_service) { instance_double(GoCardlessPro::Services::PaymentsService) }
  let(:gocardless_mandates_service) { instance_double(GoCardlessPro::Services::MandatesService) }
  let(:gocardless_list_response) { instance_double(GoCardlessPro::ListResponse) }
  let(:argument) { invoice }
  let(:code) { "gocardless_1" }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      total_amount_cents: 200,
      currency: "EUR",
      ready_for_payment_processing: true
    )
  end

  describe "#update_payment_status" do
    let(:payment) do
      create(
        :payment,
        payable: invoice,
        provider_payment_id: "ch_123456",
        status: "pending_submission",
        payment_provider: gocardless_payment_provider
      )
    end

    before do
      payment
    end

    it "updates the payment and invoice payment_status" do
      result = gocardless_service.update_payment_status(
        provider_payment_id: "ch_123456",
        status: "paid_out"
      )

      expect(result).to be_success
      expect(result.payment.status).to eq("paid_out")
      expect(result.payment.payable_payment_status).to eq("succeeded")
      expect(result.invoice.reload).to have_attributes(
        payment_status: "succeeded",
        ready_for_payment_processing: false,
        total_paid_amount_cents: 200
      )
    end

    it "enqueues a SendWebhookJob for payment.succeeded" do
      expect do
        gocardless_service.update_payment_status(
          provider_payment_id: "ch_123456",
          status: "paid_out"
        )
      end.to have_enqueued_job(SendWebhookJob).with("payment.succeeded", Payment)
    end

    context "when status is failed" do
      it "updates the payment and invoice status" do
        result = gocardless_service.update_payment_status(
          provider_payment_id: "ch_123456",
          status: "failed"
        )

        expect(result).to be_success
        expect(result.payment.status).to eq("failed")
        expect(result.payment.payable_payment_status).to eq("failed")
        expect(result.invoice.reload).to have_attributes(
          payment_status: "failed",
          ready_for_payment_processing: true
        )
      end
    end

    context "when invoice is already payment_succeeded" do
      before { invoice.payment_succeeded! }

      it "does not update the status of invoice and payment" do
        result = gocardless_service.update_payment_status(
          provider_payment_id: "ch_123456",
          status: "paid_out"
        )

        expect(result).to be_success
        expect(result.invoice.payment_status).to eq("succeeded")
      end
    end

    context "with invalid status" do
      it "does not update the payment_status of invoice" do
        result = gocardless_service.update_payment_status(
          provider_payment_id: "ch_123456",
          status: "foo-bar"
        )

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:payable_payment_status)
        expect(result.error.messages[:payable_payment_status]).to include("value_is_invalid")
      end
    end

    context "when invoice is not passed to constructor" do
      let(:argument) { nil }

      it "updates the payment and invoice payment_status" do
        result = gocardless_service.update_payment_status(
          provider_payment_id: "ch_123456",
          status: "paid_out"
        )

        expect(result).to be_success
        expect(result.payment.status).to eq("paid_out")
        expect(result.payment.payable_payment_status).to eq("succeeded")
        expect(result.invoice.reload).to have_attributes(
          payment_status: "succeeded",
          ready_for_payment_processing: false
        )
      end
    end
  end
end
