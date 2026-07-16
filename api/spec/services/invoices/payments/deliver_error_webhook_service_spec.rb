# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Payments::DeliverErrorWebhookService do
  subject(:webhook_service) { described_class.new(invoice, params) }

  let(:params) do
    {
      "provider_customer_id" => "customer",
      "provider_error" => {
        "error_message" => "message",
        "error_code" => "code"
      }
    }.with_indifferent_access
  end

  describe ".call_async" do
    context "when invoice is visible?" do
      let(:invoice) { create(:invoice, invoice_type: :subscription, status: :finalized) }

      it "enqueues a job to send an invoice payment failure webhook" do
        expect do
          webhook_service.call_async
        end.to have_enqueued_job(SendWebhookJob).once.and(
          have_enqueued_job(SendWebhookJob).with("invoice.payment_failure", invoice, params)
        )
      end

      it "produces an activity log" do
        webhook_service.call_async

        expect(Utils::ActivityLog).to have_produced("invoice.payment_failure").with(invoice)
      end
    end

    context "when invoice is invisible" do
      let(:invoice) { create(:invoice, invoice_type: :credit, status: :generating) }

      it "does not send the invoice payment failure webhook" do
        expect do
          webhook_service.call_async
        end.not_to have_enqueued_job(SendWebhookJob)
      end
    end

    context "when the invoice is a subscription invoice and open" do
      let(:invoice) { create(:invoice, invoice_type: :subscription, status: :open) }

      it "does not send any webhook" do
        expect do
          webhook_service.call_async
        end.not_to have_enqueued_job(SendWebhookJob)
      end
    end

    context "when the invoice is credit?" do
      let(:invoiceable) { create(:wallet_transaction) }
      let(:fee) { create(:fee, fee_type: :credit, invoice: invoice, invoiceable:) }

      before do
        fee
      end

      context "when the invoice is open?" do
        let(:invoice) { create(:invoice, :credit, status: :open) }

        it "enqueues a job to send a wallet transaction and an invoice payment failure webhook" do
          expect do
            webhook_service.call_async
          end.to have_enqueued_job(SendWebhookJob).once
            .and(have_enqueued_job(SendWebhookJob).with("wallet_transaction.payment_failure", WalletTransaction, params))
        end

        it "produces an activity log" do
          webhook_service.call_async

          expect(Utils::ActivityLog).to have_produced("wallet_transaction.payment_failure").with(invoiceable)
        end
      end

      context "when the invoice is visible?" do
        let(:invoice) { create(:invoice, :credit, status: :finalized) }

        it "enqueues a job to send an invoice payment failure webhook" do
          expect do
            webhook_service.call_async
          end.to have_enqueued_job(SendWebhookJob).with("wallet_transaction.payment_failure", WalletTransaction, params)
            .and(have_enqueued_job(SendWebhookJob).with("invoice.payment_failure", invoice, params))
        end

        it "produces an activity log" do
          webhook_service.call_async

          expect(Utils::ActivityLog).to have_produced("wallet_transaction.payment_failure").with(invoiceable)
        end
      end
    end
  end
end
