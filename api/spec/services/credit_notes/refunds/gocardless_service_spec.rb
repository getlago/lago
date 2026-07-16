# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::Refunds::GocardlessService do
  subject(:gocardless_service) { described_class.new(credit_note) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:organization) { customer.organization }
  let(:gocardless_payment_provider) { create(:gocardless_provider, organization:, code:) }
  let(:gocardless_customer) { create(:gocardless_customer, customer:) }
  let(:gocardless_client) { instance_double(GoCardlessPro::Client) }
  let(:gocardless_refunds_service) { instance_double(GoCardlessPro::Services::RefundsService) }
  let(:code) { "gocardless_1" }
  let(:payment) do
    create(
      :payment,
      payment_provider: gocardless_payment_provider,
      payment_provider_customer: gocardless_customer,
      amount_cents: 200,
      amount_currency: "CHF",
      payable: credit_note.invoice
    )
  end

  let(:credit_note) do
    create(
      :credit_note,
      customer:,
      invoice:,
      refund_amount_cents: 134,
      refund_amount_currency: "CHF",
      refund_status: :pending
    )
  end

  describe "#create" do
    before do
      payment

      allow(GoCardlessPro::Client).to receive(:new)
        .and_return(gocardless_client)
      allow(gocardless_client).to receive(:refunds)
        .and_return(gocardless_refunds_service)
      allow(gocardless_refunds_service).to receive(:create)
        .and_return(GoCardlessPro::Resources::Refund.new(
          "id" => "re_123456",
          "amount" => 134,
          "currency" => "chf",
          "status" => "paid"
        ))
      allow(SegmentTrackJob).to receive(:perform_later)
    end

    it "creates a gocardless refund" do
      result = gocardless_service.create

      expect(result).to be_success

      expect(result.refund.id).to be_present

      expect(result.refund.credit_note).to eq(credit_note)
      expect(result.refund.refundable).to eq(credit_note)
      expect(result.refund.reason).to eq("credit_note")
      expect(result.refund.payment).to eq(payment)
      expect(result.refund.payment_provider).to eq(gocardless_payment_provider)
      expect(result.refund.payment_provider_customer).to eq(gocardless_customer)
      expect(result.refund.amount_cents).to eq(134)
      expect(result.refund.amount_currency).to eq("CHF")
      expect(result.refund.status).to eq("paid")
      expect(result.refund.provider_refund_id).to eq("re_123456")

      expect(result.credit_note).to be_succeeded
    end

    it "call SegmentTrackJob" do
      gocardless_service.create

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: "refund_status_changed",
        properties: {
          organization_id: credit_note.organization.id,
          credit_note_id: credit_note.id,
          refund_status: "paid"
        }
      )
    end

    context "with an error on gocardless" do
      before do
        allow(gocardless_refunds_service).to receive(:create)
          .and_raise(GoCardlessPro::Error.new("code" => "code", "message" => "error"))
      end

      it "delivers an error webhook" do
        expect { gocardless_service.create }
          .to raise_error(GoCardlessPro::Error)

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "credit_note.provider_refund_failure",
            credit_note,
            provider_customer_id: gocardless_customer.provider_customer_id,
            provider_error: {
              message: "error",
              error_code: "code"
            }
          )
      end

      it "produces an activity log" do
        expect { gocardless_service.create }
          .to raise_error(GoCardlessPro::Error)

        expect(Utils::ActivityLog).to have_produced("credit_note.refund_failure").with(credit_note)
      end
    end

    context "with a validation error on gocardless" do
      before do
        allow(gocardless_refunds_service).to receive(:create)
          .and_raise(GoCardlessPro::ValidationError.new("code" => "code", "message" => "error"))
      end

      it "delivers an error webhook and returns an empty result" do
        expect(gocardless_service.create).to be_success

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "credit_note.provider_refund_failure",
            credit_note,
            provider_customer_id: gocardless_customer.provider_customer_id,
            provider_error: {
              message: "error",
              error_code: "code"
            }
          )
      end
    end

    context "when credit note does not have a refund amount" do
      let(:credit_note) do
        create(
          :credit_note,
          customer:,
          refund_amount_cents: 0,
          refund_amount_currency: "CHF"
        )
      end

      it "does not create a refund" do
        result = gocardless_service.create

        expect(result).to be_success

        expect(result.credit_note).to eq(credit_note)
        expect(result.refund).to be_nil

        expect(gocardless_refunds_service).not_to have_received(:create)
      end
    end

    context "when invoice does not have a payment" do
      let(:payment) { nil }

      it "does not create a refund" do
        result = gocardless_service.create

        expect(result).to be_success

        expect(result.credit_note).to eq(credit_note)
        expect(result.refund).to be_nil

        expect(gocardless_refunds_service).not_to have_received(:create)
      end
    end

    context "when dispute was lost" do
      let(:invoice) { create(:invoice, :dispute_lost, customer:, organization:) }

      it "does not create a refund" do
        result = gocardless_service.create

        expect(result).to be_success

        expect(result.credit_note).to eq(credit_note)
        expect(result.refund).to be_nil

        expect(gocardless_refunds_service).not_to have_received(:create)
      end
    end

    context "when payment provider customer was discarded" do
      before { gocardless_customer.discard }

      it "creates a gocardless refund" do
        result = gocardless_service.create

        expect(result).to be_success

        expect(result.refund.id).to be_present

        expect(result.refund.credit_note).to eq(credit_note)
        expect(result.refund.payment).to eq(payment)
        expect(result.refund.payment_provider).to eq(gocardless_payment_provider)
        expect(result.refund.payment_provider_customer).to eq(gocardless_customer)
        expect(result.refund.amount_cents).to eq(134)
        expect(result.refund.amount_currency).to eq("CHF")
        expect(result.refund.status).to eq("paid")
        expect(result.refund.provider_refund_id).to eq("re_123456")

        expect(result.credit_note).to be_succeeded
      end
    end
  end

  describe "#update_status" do
    let(:refund) do
      create(:refund, credit_note:)
    end

    before do
      payment
      refund
      credit_note.pending!
    end

    it "updates the refund status" do
      result = gocardless_service.update_status(
        provider_refund_id: refund.provider_refund_id,
        status: "paid"
      )

      expect(result).to be_success

      expect(result.refund).to eq(refund)
      expect(result.refund.status).to eq("paid")

      expect(result.credit_note).to be_succeeded
    end

    it "calls SegmentTrackJob" do
      allow(SegmentTrackJob).to receive(:perform_later)

      gocardless_service.update_status(
        provider_refund_id: refund.provider_refund_id,
        status: "paid"
      )

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: "refund_status_changed",
        properties: {
          organization_id: credit_note.organization.id,
          credit_note_id: credit_note.id,
          refund_status: "paid"
        }
      )
    end

    context "when refund is not found" do
      it "returns an empty result" do
        result = gocardless_service.update_status(
          provider_refund_id: "foo",
          status: "paid"
        )

        expect(result).to be_success
        expect(result.refund).to be_nil
      end
    end

    context "when status is not valid" do
      it "fails" do
        result = gocardless_service.update_status(
          provider_refund_id: refund.provider_refund_id,
          status: "invalid"
        )

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:refund_status]).to include("value_is_invalid")
      end
    end

    context "when status is failed" do
      before do
        gocardless_service
      end

      it "delivers an error webhook" do
        result = gocardless_service.update_status(
          provider_refund_id: refund.provider_refund_id,
          status: "failed"
        )

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("refund_failed")
        expect(result.error.error_message).to eq("Refund failed to perform")

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "credit_note.provider_refund_failure",
            credit_note,
            provider_customer_id: gocardless_customer.provider_customer_id,
            provider_error: {
              message: "Payment refund failed",
              error_code: nil
            }
          )
      end

      it "produces an activity log" do
        gocardless_service.update_status(
          provider_refund_id: refund.provider_refund_id,
          status: "failed"
        )

        expect(Utils::ActivityLog).to have_produced("credit_note.refund_failure").with(credit_note)
      end
    end
  end
end
