# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::LoseDisputeService do
  subject(:lose_dispute_service) { described_class.new(invoice:) }

  describe "#call" do
    context "when invoice does not exist" do
      let(:invoice) { nil }

      it "returns a failure" do
        result = lose_dispute_service.call

        expect(result).not_to be_success

        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("invoice")
      end

      it "does not enqueue a send webhook job for the invoice" do
        expect { lose_dispute_service.call }.not_to have_enqueued_job(SendWebhookJob)
      end
    end

    context "when invoice exists" do
      let(:invoice) { create(:invoice, status:) }

      context "when the invoice is voided" do
        let(:status) { :voided }

        it "marks the dispute as lost" do
          result = lose_dispute_service.call

          expect(result).to be_success
          expect(result.invoice.payment_dispute_lost_at).to be_present
        end

        it "enqueues a send webhook job for the invoice" do
          expect do
            lose_dispute_service.call
          end.to have_enqueued_job(SendWebhookJob).with("invoice.payment_dispute_lost", invoice, provider_error: nil)
        end

        it "enqueues a sync void invoice job" do
          expect do
            lose_dispute_service.call
          end.to have_enqueued_job(Invoices::ProviderTaxes::VoidJob).with(invoice:)
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
          expect(result.invoice.payment_dispute_lost_at).to be_present
        end

        it "enqueues a send webhook job for the invoice" do
          expect do
            lose_dispute_service.call
          end.to have_enqueued_job(SendWebhookJob).with("invoice.payment_dispute_lost", invoice, provider_error: nil)
        end

        it "enqueues a sync void invoice job" do
          expect do
            lose_dispute_service.call
          end.to have_enqueued_job(Invoices::ProviderTaxes::VoidJob).with(invoice:)
        end
      end
    end
  end
end
