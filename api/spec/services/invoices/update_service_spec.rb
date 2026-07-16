# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::UpdateService do
  subject(:invoice_service) do
    described_class.new(invoice:, params: update_args, webhook_notification:)
  end

  let(:invoice) { create(:invoice, payment_overdue: true) }
  let(:invoice_id) { invoice.id }
  let(:webhook_notification) { false }

  let(:update_args) do
    {
      payment_status: "succeeded",
      total_paid_amount_cents: 100
    }
  end

  let(:result) { invoice_service.call }

  describe "call" do
    it "updates the invoice" do
      expect(result).to be_success
      expect(result.invoice).to eq(invoice)
      expect(result.invoice).to have_attributes(
        payment_overdue: false,
        payment_status: update_args[:payment_status],
        total_paid_amount_cents: update_args[:total_paid_amount_cents]
      )
    end

    context "when the invoice settles with an open checkout session" do
      before { create(:payment_intent, invoice:) }

      it "enqueues a job to expire the checkout session" do
        expect { result }.to have_enqueued_job_after_commit(PaymentIntents::ExpireJob).with(invoice)
      end

      context "when the invoice was already succeeded" do
        let(:invoice) { create(:invoice, payment_status: :succeeded) }

        it "does not enqueue the expire job" do
          expect { result }.not_to have_enqueued_job(PaymentIntents::ExpireJob)
        end
      end
    end

    context "when the invoice settles without an open checkout session" do
      it "does not enqueue the expire job" do
        expect { result }.not_to have_enqueued_job(PaymentIntents::ExpireJob)
      end
    end

    context "when invoices is included in a payment request" do
      let(:customer) do
        create(
          :customer,
          last_dunning_campaign_attempt: 3,
          last_dunning_campaign_attempt_at: 1.day.ago
        )
      end

      let(:invoice) { create(:invoice, payment_overdue: true, customer:) }

      let(:payment_request) do
        create(:payment_request, customer:, invoices: [invoice])
      end

      before do
        payment_request
      end

      it "does not reset customer dunning campaign status counters" do
        expect { result && customer.reload }
          .to not_change(customer, :last_dunning_campaign_attempt)
          .and not_change { customer.last_dunning_campaign_attempt_at.to_i }
      end

      context "when payment request belongs to a dunning campaign" do
        let(:dunning_campaign) { create(:dunning_campaign) }
        let(:payment_request) do
          create(:payment_request, customer:, invoices: [invoice], dunning_campaign:)
        end

        it "resets customer dunning campaign status counters for the invoice currency" do
          expect { result && customer.reload }
            .to change(customer, :last_dunning_campaign_attempt).to(0)
            .and change(customer, :last_dunning_campaign_attempt_at).to(nil)
            .and change(customer, :dunning_currency_attempts).to({"EUR" => 0})
        end
      end
    end

    context "when updating payment status" do
      context "when invoice is in draft status" do
        let(:invoice) { create(:invoice, :draft) }

        it "does not update the invoice" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("payment_status_update_on_draft_invoice")
        end
      end

      context "when invoice is not in draft status" do
        it "updates the invoice" do
          expect(result).to be_success
          expect(result.invoice).to eq(invoice)
          expect(result.invoice.payment_status).to eq(update_args[:payment_status])
        end
      end
    end

    context "with attached fees" do
      it "enqueues a job to update the payment_status of the fees" do
        expect { result }.to have_enqueued_job_after_commit(Invoices::UpdateFeesPaymentStatusJob).with(invoice)
      end
    end

    context "with metadata" do
      let(:invoice_metadata) { create(:invoice_metadata, invoice:) }
      let(:another_invoice_metadata) { create(:invoice_metadata, invoice:, key: "test", value: "1") }
      let(:update_args) do
        {
          metadata: [
            {
              id: invoice_metadata.id,
              key: "new key",
              value: "new value"
            },
            {
              key: "Added key",
              value: "Added value"
            }
          ]
        }
      end

      before do
        invoice_metadata
        another_invoice_metadata
      end

      it "updates metadata" do
        metadata_keys = result.invoice.metadata.pluck(:key)
        metadata_ids = result.invoice.metadata.pluck(:id)

        expect(result.invoice.metadata.count).to eq(2)
        expect(metadata_keys).to eq(["new key", "Added key"])
        expect(metadata_ids).to include(invoice_metadata.id)
        expect(metadata_ids).not_to include(another_invoice_metadata.id)
      end

      context "when invoice is in draft status" do
        let(:invoice) { create(:invoice, status: "draft") }

        it "fails to update metadata" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("metadata_on_draft_invoice")
        end
      end

      context "when more than five metadata objects are provided" do
        let(:update_args) do
          {
            metadata: [
              {
                id: invoice_metadata.id,
                key: "new key",
                value: "new value"
              },
              {
                key: "Added key1",
                value: "Added value1"
              },
              {
                key: "Added key2",
                value: "Added value2"
              },
              {
                key: "Added key3",
                value: "Added value3"
              },
              {
                key: "Added key4",
                value: "Added value4"
              },
              {
                key: "Added key5",
                value: "Added value5"
              }
            ]
          }
        end

        it "fails to update invoice with metadata" do
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages.keys).to include(:metadata)
          expect(result.error.messages[:metadata]).to include("invalid_count")
        end
      end
    end

    context "when invoice has hubspot integration" do
      let(:sync_invoices) { true }
      let(:organization) { create(:organization) }
      let(:customer) { create(:customer, organization:) }
      let(:integration) { create(:hubspot_integration, organization:, sync_invoices:) }
      let(:integration_customer) { create(:hubspot_customer, integration:, customer:, organization:) }
      let(:invoice) { create(:invoice, customer: integration_customer.customer, organization:) }

      it "enqueues a job to update the hubspot invoice" do
        expect { result }.to have_enqueued_job_after_commit(Integrations::Aggregator::Invoices::Hubspot::UpdateJob).with(invoice:)
      end

      context "when it should not sync hubspot invoices" do
        let(:sync_invoices) { false }

        it "does not enqueue a job to update the hubspot invoice" do
          result

          expect(Integrations::Aggregator::Invoices::Hubspot::UpdateJob).not_to have_been_enqueued
        end
      end
    end

    context "when invoice type is credit" do
      let(:subscription) { create(:subscription, customer: invoice.customer) }
      let(:wallet) { create(:wallet, customer: invoice.customer, balance: 10.0, credits_balance: 10.0) }
      let(:wallet_transaction) do
        create(:wallet_transaction, wallet:, amount: 15.0, credit_amount: 15.0, status: "pending")
      end
      let(:fee) do
        create(
          :fee,
          fee_type: "credit",
          invoiceable_type: "WalletTransaction",
          invoiceable_id: wallet_transaction.id,
          invoice:
        )
      end

      before do
        wallet_transaction
        fee
        subscription
        invoice.update(invoice_type: "credit")
      end

      context "when payment_status is succeeded" do
        let(:update_args) { {payment_status: "succeeded"} }

        it "calls Invoices::PrepaidCreditJob with the correct arguments" do
          expect { result }.to have_enqueued_job_after_commit(Invoices::PrepaidCreditJob).with(invoice, :succeeded)
        end
      end

      context "when payment_status is failed" do
        let(:update_args) { {payment_status: "failed"} }

        it "calls Invoices::PrepaidCreditJob with the correct arguments" do
          expect { result }.to have_enqueued_job_after_commit(Invoices::PrepaidCreditJob).with(invoice, :failed)
        end
      end
    end

    context "when invoice is subscription_gated and payment_status changes" do
      let(:subscription) do
        create(:subscription, :incomplete, :with_activation_rules,
          organization: invoice.organization, customer: invoice.customer, plan:,
          activation_rules_config: [{type: "payment", timeout_hours: 48, status: "pending"}])
      end
      let(:plan) { create(:plan, organization: invoice.organization, pay_in_advance: true) }
      let(:invoice) { create(:invoice, status: :open, invoice_type: :subscription, payment_overdue: false) }

      before { create(:invoice_subscription, invoice:, subscription:) }

      context "when payment_status is succeeded" do
        let(:update_args) { {payment_status: "succeeded"} }

        it "enqueues ResolveJob" do
          expect { invoice_service.call }
            .to have_enqueued_job_after_commit(Subscriptions::ActivationRules::Payment::ResolveJob)
            .with(subscription, invoice, :succeeded)
        end
      end

      context "when payment_status is failed" do
        let(:update_args) { {payment_status: "failed"} }

        it "enqueues ResolveJob" do
          expect { invoice_service.call }
            .to have_enqueued_job_after_commit(Subscriptions::ActivationRules::Payment::ResolveJob)
            .with(subscription, invoice, :failed)
        end
      end
    end

    context "with payment_status update and notification is turned on" do
      let(:webhook_notification) { true }

      context "when invoice is visible" do
        it "delivers a webhook" do
          expect { result }.to have_enqueued_job_after_commit(SendWebhookJob).with("invoice.payment_status_updated", invoice)
        end

        it "produces an activity log" do
          result

          expect(Utils::ActivityLog).to have_produced("invoice.payment_status_updated").after_commit.with(invoice)
        end
      end

      context "when invoice is invisible" do
        before { invoice.update! status: :open }

        it "does not deliver a webhook" do
          expect { result }.not_to have_enqueued_job(SendWebhookJob)
        end
      end

      context "when payment status has not changed" do
        let(:invoice) { create(:invoice, payment_status: :succeeded) }

        it "does not deliver a webhook" do
          expect { result }.not_to have_enqueued_job(SendWebhookJob)
        end
      end
    end

    context "when invoice does not exist" do
      let(:invoice) { nil }

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("invoice_not_found")
      end
    end

    context "when invoice payment_status is invalid" do
      let(:update_args) do
        {
          payment_status: "Foo Bar"
        }
      end

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to include(:payment_status)
        expect(result.error.messages[:payment_status]).to include("value_is_invalid")
      end
    end

    context "with validation error" do
      before do
        invoice.issuing_date = nil
        invoice.save(validate: false)
      end

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:issuing_date]).to eq(["value_is_mandatory"])
      end
    end
  end
end
