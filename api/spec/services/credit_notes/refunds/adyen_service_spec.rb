# frozen_string_literal: true

require "rails_helper"

RSpec.describe CreditNotes::Refunds::AdyenService do
  subject(:adyen_service) { described_class.new(credit_note) }

  let(:customer) { create(:customer, payment_provider_code: code) }
  let(:organization) { customer.organization }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:adyen_payment_provider) { create(:adyen_provider, organization:, code:) }
  let(:adyen_customer) { create(:adyen_customer, customer:) }
  let(:adyen_client) { instance_double(Adyen::Client) }
  let(:modifications_api) { Adyen::ModificationsApi.new(adyen_client, 70) }
  let(:checkout) { Adyen::Checkout.new(adyen_client, 70) }
  let(:refunds_response) { generate(:adyen_refunds_response) }
  let(:code) { "adyen_1" }
  let(:payment) do
    create(
      :payment,
      payment_provider: adyen_payment_provider,
      payment_provider_customer: adyen_customer,
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

      allow(Adyen::Client).to receive(:new)
        .and_return(adyen_client)
      allow(adyen_client).to receive(:checkout)
        .and_return(checkout)
      allow(checkout).to receive(:modifications_api)
        .and_return(modifications_api)
      allow(modifications_api).to receive(:refund_captured_payment)
        .and_return(refunds_response)
      allow(SegmentTrackJob).to receive(:perform_later)
    end

    it "creates a adyen refund and a refund" do
      result = adyen_service.create

      expect(result).to be_success

      expect(result.refund.id).to be_present

      expect(result.refund.credit_note).to eq(credit_note)
      expect(result.refund.refundable).to eq(credit_note)
      expect(result.refund.reason).to eq("credit_note")
      expect(result.refund.payment).to eq(payment)
      expect(result.refund.payment_provider).to eq(adyen_payment_provider)
      expect(result.refund.payment_provider_customer).to eq(adyen_customer)
      expect(result.refund.amount_cents).to eq(134)
      expect(result.refund.amount_currency).to eq("CHF")
      expect(result.refund.status).to eq("pending")
      expect(result.refund.provider_refund_id).to eq(refunds_response.response["pspReference"])

      expect(result.credit_note).not_to be_succeeded
      expect(result.credit_note.refunded_at).not_to be_present
    end

    it "call SegmentTrackJob" do
      adyen_service.create

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: "refund_status_changed",
        properties: {
          organization_id: credit_note.organization.id,
          credit_note_id: credit_note.id,
          refund_status: "pending"
        }
      )
    end

    context "with an error on adyen" do
      before do
        allow(modifications_api).to receive(:refund_captured_payment)
          .and_raise(Adyen::AdyenError.new(nil, nil, "error"))
      end

      it "delivers an error webhook" do
        expect { adyen_service.create }
          .to raise_error(Adyen::AdyenError)

        expect(SendWebhookJob).to have_been_enqueued
          .with(
            "credit_note.provider_refund_failure",
            credit_note,
            provider_customer_id: adyen_customer.provider_customer_id,
            provider_error: {
              message: "error",
              error_code: nil
            }
          )
      end

      it "produces an activity log" do
        expect { adyen_service.create }
          .to raise_error(Adyen::AdyenError)

        expect(Utils::ActivityLog).to have_produced("credit_note.refund_failure").with(credit_note)
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
        result = adyen_service.create

        expect(result).to be_success

        expect(result.credit_note).to eq(credit_note)
        expect(result.refund).to be_nil

        expect(modifications_api).not_to have_received(:refund_captured_payment)
      end
    end

    context "when invoice does not have a payment" do
      let(:payment) { nil }

      it "does not create a refund" do
        result = adyen_service.create

        expect(result).to be_success

        expect(result.credit_note).to eq(credit_note)
        expect(result.refund).to be_nil

        expect(modifications_api).not_to have_received(:refund_captured_payment)
      end
    end

    context "when dispute was lost" do
      let(:invoice) { create(:invoice, :dispute_lost, customer:, organization:) }

      it "does not create a refund" do
        result = adyen_service.create

        expect(result).to be_success

        expect(result.credit_note).to eq(credit_note)
        expect(result.refund).to be_nil

        expect(modifications_api).not_to have_received(:refund_captured_payment)
      end
    end

    context "when payment provider customer was discarded" do
      before { adyen_customer.discard }

      it "creates a adyen refund and a refund" do
        result = adyen_service.create

        expect(result).to be_success

        expect(result.refund.id).to be_present

        expect(result.refund.credit_note).to eq(credit_note)
        expect(result.refund.payment).to eq(payment)
        expect(result.refund.payment_provider).to eq(adyen_payment_provider)
        expect(result.refund.payment_provider_customer).to eq(adyen_customer)
        expect(result.refund.amount_cents).to eq(134)
        expect(result.refund.amount_currency).to eq("CHF")
        expect(result.refund.status).to eq("pending")
        expect(result.refund.provider_refund_id).to eq(refunds_response.response["pspReference"])

        expect(result.credit_note).not_to be_succeeded
        expect(result.credit_note.refunded_at).not_to be_present
      end
    end
  end

  describe "#update_status" do
    let(:refund) do
      create(:refund, credit_note:)
    end

    before { credit_note.pending! }

    it "updates the refund status" do
      result = adyen_service.update_status(
        provider_refund_id: refund.provider_refund_id,
        status: "succeeded"
      )

      expect(result).to be_success

      expect(result.refund).to eq(refund)
      expect(result.refund.status).to eq("succeeded")

      expect(result.credit_note).to be_succeeded
    end

    it "calls SegmentTrackJob" do
      allow(SegmentTrackJob).to receive(:perform_later)

      adyen_service.update_status(
        provider_refund_id: refund.provider_refund_id,
        status: "succeeded"
      )

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: "refund_status_changed",
        properties: {
          organization_id: credit_note.organization.id,
          credit_note_id: credit_note.id,
          refund_status: "succeeded"
        }
      )
    end

    context "when refund is not found" do
      let(:refund) { nil }

      it "returns an empty result" do
        result = adyen_service.update_status(
          provider_refund_id: "foo",
          status: "succeeded"
        )

        expect(result).to be_success
        expect(result.refund).to be_nil
      end

      context "with invoice id in metadata" do
        it "returns an empty result" do
          result = adyen_service.update_status(
            provider_refund_id: "foo",
            status: "succeeded",
            metadata: {lago_invoice_id: SecureRandom.uuid}
          )

          expect(result).to be_success
          expect(result.refund).to be_nil
        end

        context "when invoice belongs to lago" do
          let(:invoice) { create(:invoice) }

          it "returns a not found failure" do
            result = adyen_service.update_status(
              provider_refund_id: "re_123456",
              status: "succeeded",
              metadata: {lago_invoice_id: invoice.id}
            )

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::NotFoundFailure)
            expect(result.error.message).to eq("adyen_refund_not_found")
          end
        end
      end
    end

    context "when status is not valid" do
      it "fails" do
        result = adyen_service.update_status(
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
        adyen_customer
      end

      it "delivers an error webhook" do
        result = adyen_service.update_status(
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
            provider_customer_id: adyen_customer.provider_customer_id,
            provider_error: {
              message: "Payment refund failed",
              error_code: nil
            }
          )
      end

      it "produces an activity log" do
        adyen_service.update_status(
          provider_refund_id: refund.provider_refund_id,
          status: "failed"
        )

        expect(Utils::ActivityLog).to have_produced("credit_note.refund_failure").with(credit_note)
      end
    end
  end
end
