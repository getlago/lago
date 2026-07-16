# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivationRules::Payment::ResolveService do
  subject(:result) { described_class.call(subscription:, invoice:, payment_status:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, pay_in_advance: true) }
  let(:subscription) { create(:subscription, :incomplete, organization:, customer:, plan:) }
  let(:rule) { create(:subscription_activation_rule, subscription:, status: "pending") }
  let(:invoice) do
    create(:invoice, organization:, customer:, status: :open, invoice_type: :subscription,
      total_amount_cents: 100, fees_amount_cents: 100)
  end
  let(:payment_status) { :failed }

  before do
    rule
    create(:invoice_subscription, invoice:, subscription:)
  end

  context "when subscription is not incomplete" do
    let(:subscription) { create(:subscription, organization:, customer:, plan:) }

    it "returns early without changes" do
      result

      expect(rule.reload.status).to eq("pending")
      expect(invoice.reload.status).to eq("open")
    end
  end

  context "when invoice is not open" do
    before { invoice.update!(status: :finalized) }

    it "returns early without changes" do
      result

      expect(rule.reload.status).to eq("pending")
      expect(subscription.reload).to be_incomplete
    end
  end

  context "when invoice is not a subscription invoice" do
    let(:invoice) do
      create(:invoice, :credit, organization:, customer:, status: :open,
        total_amount_cents: 100, fees_amount_cents: 100)
    end

    it "returns early without changes" do
      result

      expect(rule.reload.status).to eq("pending")
      expect(subscription.reload).to be_incomplete
    end
  end

  context "when payment_status is succeeded" do
    let(:payment_status) { :succeeded }

    it "marks the activation rule as satisfied" do
      result

      expect(rule.reload.status).to eq("satisfied")
    end

    it "finalizes the invoice" do
      result

      expect(invoice.reload.status).to eq("finalized")
    end

    it "activates the subscription" do
      freeze_time do
        result

        expect(subscription.reload).to be_active
        expect(subscription.activated_at).to eq(Time.current)
      end
    end

    it "sends a subscription.started webhook" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", subscription)
    end

    it "sends an invoice.created webhook" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("invoice.created", invoice)
    end

    it "produces an invoice.created activity log" do
      result

      expect(Utils::ActivityLog).to have_produced("invoice.created").with(invoice)
    end

    it "enqueues GenerateDocumentsJob with notify false" do
      result

      expect(Invoices::GenerateDocumentsJob).to have_been_enqueued.with(invoice:, notify: false)
    end

    context "with lago_premium", :premium do
      it "enqueues GenerateDocumentsJob with notify true" do
        result

        expect(Invoices::GenerateDocumentsJob).to have_been_enqueued.with(invoice:, notify: true)
      end

      context "when billing entity does not have invoice.finalized email setting" do
        before { invoice.billing_entity.update!(email_settings: []) }

        it "enqueues GenerateDocumentsJob with notify false" do
          result

          expect(Invoices::GenerateDocumentsJob).to have_been_enqueued.with(invoice:, notify: false)
        end
      end
    end

    it "tracks invoice creation in segment" do
      allow(Utils::SegmentTrack).to receive(:invoice_created)

      result

      expect(Utils::SegmentTrack).to have_received(:invoice_created).with(invoice)
    end

    context "with the succeeded payment for the invoice" do
      let(:payment) do
        create(:payment, payable: invoice, organization:, customer:,
          payable_payment_status: :succeeded, provider_payment_id: "pi_123")
      end

      before { payment }

      it "enqueues UpdatePaymentReferenceJob so the PSP-side reference matches the finalized invoice" do
        result

        expect(PaymentProviders::UpdatePaymentReferenceJob).to have_been_enqueued.with(payment)
      end
    end

    context "when invoice should be synced to accounting integration" do
      before { allow(invoice).to receive(:should_sync_invoice?).and_return(true) }

      it "enqueues Aggregator::Invoices::CreateJob" do
        result

        expect(Integrations::Aggregator::Invoices::CreateJob).to have_been_enqueued.with(invoice:)
      end
    end

    context "when invoice should not be synced to accounting integration" do
      before { allow(invoice).to receive(:should_sync_invoice?).and_return(false) }

      it "does not enqueue Aggregator::Invoices::CreateJob" do
        result

        expect(Integrations::Aggregator::Invoices::CreateJob).not_to have_been_enqueued
      end
    end

    context "when invoice should be synced to hubspot" do
      before { allow(invoice).to receive(:should_sync_hubspot_invoice?).and_return(true) }

      it "enqueues Aggregator::Invoices::Hubspot::CreateJob" do
        result

        expect(Integrations::Aggregator::Invoices::Hubspot::CreateJob).to have_been_enqueued.with(invoice:)
      end
    end

    context "when invoice should not be synced to hubspot" do
      before { allow(invoice).to receive(:should_sync_hubspot_invoice?).and_return(false) }

      it "does not enqueue Aggregator::Invoices::Hubspot::CreateJob" do
        result

        expect(Integrations::Aggregator::Invoices::Hubspot::CreateJob).not_to have_been_enqueued
      end
    end

    context "when customer has a tax provider integration" do
      let(:integration) { create(:anrok_integration, organization:) }

      before do
        create(:anrok_customer, integration:, customer:)
      end

      it "enqueues Aggregator::Taxes::Invoices::CreateJob to commit the finalized tax record" do
        result

        expect(Integrations::Aggregator::Taxes::Invoices::CreateJob).to have_been_enqueued.with(invoice:)
      end
    end

    context "when customer does not have a tax provider integration" do
      it "does not enqueue Aggregator::Taxes::Invoices::CreateJob" do
        result

        expect(Integrations::Aggregator::Taxes::Invoices::CreateJob).not_to have_been_enqueued
      end
    end

    context "when subscription is already active (idempotency)" do
      let(:subscription) { create(:subscription, organization:, customer:, plan:) }

      it "returns early without changes" do
        result

        expect(rule.reload.status).to eq("pending")
        expect(invoice.reload.status).to eq("open")
      end
    end
  end

  context "when payment_status is failed" do
    let(:payment_status) { :failed }

    it "marks the activation rule as failed" do
      result

      expect(rule.reload.status).to eq("failed")
    end

    it "closes the invoice" do
      result

      expect(invoice.reload.status).to eq("closed")
    end

    it "cancels the subscription with payment_failed reason" do
      result

      expect(subscription.reload).to be_canceled
      expect(subscription.cancellation_reason).to eq("payment_failed")
    end

    it "sends a subscription.canceled webhook" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.canceled", subscription)
    end

    context "when an applied-coupon credit was consumed" do
      let(:applied_coupon) { create(:applied_coupon, customer:, organization:, status: :terminated) }
      let(:credit) { create(:credit, invoice:, organization:, applied_coupon:) }

      before { credit }

      it "enqueues an AppliedCoupons::RecreditJob" do
        result

        expect(AppliedCoupons::RecreditJob).to have_been_enqueued.with(credit)
      end
    end

    context "when a credit-note credit was consumed" do
      let(:credit_note) { create(:credit_note, customer:, organization:, invoice:, credit_status: :available) }
      let(:credit) { create(:credit_note_credit, invoice:, organization:, credit_note:) }

      before { credit }

      it "enqueues a CreditNotes::RecreditJob" do
        result

        expect(CreditNotes::RecreditJob).to have_been_enqueued.with(credit)
      end
    end

    context "when an outbound wallet transaction was consumed" do
      let(:wallet) { create(:wallet, customer:, organization:) }
      let(:wallet_transaction) { create(:wallet_transaction, wallet:, organization:, invoice:, transaction_type: :outbound) }

      before { wallet_transaction }

      it "enqueues a WalletTransactions::RecreditJob" do
        result

        expect(WalletTransactions::RecreditJob).to have_been_enqueued.with(wallet_transaction)
      end
    end
  end
end
