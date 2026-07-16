# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payments::LoseDisputeService do
  subject(:lose_dispute_service) { described_class.new(payment:) }

  describe "#call" do
    context "when payment does not exist" do
      let(:payment) { nil }

      it "returns a failure" do
        result = lose_dispute_service.call

        expect(result).to be_failure

        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("payment")
      end

      it "does not enqueue a send webhook job for the invoice" do
        expect { lose_dispute_service.call }.not_to have_enqueued_job(SendWebhookJob)
      end
    end

    context "when payable is not found" do
      let(:payment) { create(:payment, payable: create(:payment_request)) }

      before do
        payment.payable.destroy!
        payment.reload
      end

      it "marks all invoices as dispute lost" do
        result = lose_dispute_service.call

        expect(result).to be_failure

        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("payable")
      end
    end

    context "when payable is an invoice" do
      let(:payment) { create(:payment, payable: create(:invoice, status:)) }

      context "when the invoice is voided" do
        let(:status) { :voided }

        it "marks the dispute as lost" do
          result = lose_dispute_service.call

          expect(result).to be_success
          expect(result.invoices.sole.payment_dispute_lost_at).to be_present
        end

        it "enqueues a send webhook job for the invoice" do
          expect do
            lose_dispute_service.call
          end.to have_enqueued_job(SendWebhookJob).with("invoice.payment_dispute_lost", payment.payable, provider_error: nil)
        end

        it "enqueues a sync void invoice job" do
          expect do
            lose_dispute_service.call
          end.to have_enqueued_job(Invoices::ProviderTaxes::VoidJob).with(invoice: payment.payable)
        end
      end

      context "when the invoice is draft" do
        let(:status) { :draft }

        it "returns a failure" do
          result = lose_dispute_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("not_disputable")
        end

        it "does not enqueue a send webhook job for the invoice" do
          expect { lose_dispute_service.call }.not_to have_enqueued_job(SendWebhookJob)
        end
      end

      context "when the invoice is finalized" do
        let(:status) { :finalized }

        it "marks the dispute as lost" do
          result = lose_dispute_service.call

          expect(result).to be_success
          expect(result.invoices.sole.payment_dispute_lost_at).to be_present
        end

        it "enqueues a send webhook job for the invoice" do
          expect do
            lose_dispute_service.call
          end.to have_enqueued_job(SendWebhookJob).with("invoice.payment_dispute_lost", payment.payable, provider_error: nil)
        end

        it "enqueues a sync void invoice job" do
          expect do
            lose_dispute_service.call
          end.to have_enqueued_job(Invoices::ProviderTaxes::VoidJob).with(invoice: payment.payable)
        end
      end
    end

    context "when payable is a payment request" do
      let(:payment_request) { create(:payment_request, invoices: create_list(:invoice, 3)) }
      let(:payment) { create(:payment, payable: payment_request) }

      it "marks all invoices as dispute lost" do
        result = lose_dispute_service.call

        expect(result).to be_success
        expect(result.invoices.count).to eq 3
        expect(result.invoices.pluck(:payment_dispute_lost_at)).to all be_within(5.seconds).of(Time.current)
        expect(SendWebhookJob).to have_been_enqueued.exactly(3).times.with("invoice.payment_dispute_lost", Invoice, provider_error: nil)
        expect(Invoices::ProviderTaxes::VoidJob).to have_been_enqueued.exactly(3).times
      end
    end
  end
end
