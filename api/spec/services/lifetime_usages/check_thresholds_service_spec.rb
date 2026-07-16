# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsages::CheckThresholdsService, transaction: false do
  subject(:service) { described_class.new(lifetime_usage:) }

  let(:lifetime_usage) { create(:lifetime_usage, subscription:, recalculate_current_usage: true, recalculate_invoiced_usage: true, current_usage_amount_cents:) }
  let(:current_usage_amount_cents) { 0 }
  let(:subscription) { create(:subscription, customer_id: customer.id) }
  let(:organization) { subscription.organization }
  let(:customer) { create(:customer) }

  let(:billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }
  let(:charge) { create(:standard_charge, plan: subscription.plan, billable_metric:, properties: {amount: "10"}) }
  let(:timestamp) { Time.current }

  def create_thresholds(subscription, amounts:, recurring: nil)
    amounts.each do |amount|
      subscription.plan.usage_thresholds.create!(amount_cents: amount)
    end
    if recurring
      subscription.plan.usage_thresholds.create!(amount_cents: recurring, recurring: true)
    end
  end

  context "when we pass a threshold" do
    let(:current_usage_amount_cents) { 20 }
    let(:usage_threshold) { create(:usage_threshold, plan: subscription.plan, amount_cents: 10) }

    before do
      usage_threshold
      charge
    end

    it "ignores the flags" do
      service.call
      expect(lifetime_usage.recalculate_invoiced_usage).to eq true
      expect(lifetime_usage.recalculate_current_usage).to eq true
    end

    it "sends a webhook for that threshold" do
      expect { service.call }.to enqueue_job(SendWebhookJob)
        .with(
          "subscription.usage_threshold_reached",
          subscription,
          usage_threshold:
        ).on_queue(webhook_queue)
    end

    it "creates an invoice for the usage_threshold" do
      expect { service.call }.to change(Invoice, :count).by(1)
    end

    context "when there is tax provider error" do
      let(:error_result) { BaseService::Result.new.unknown_tax_failure!(code: "tax_error", message: "") }

      before do
        allow(Invoices::ProgressiveBillingService).to receive(:call).and_return(error_result)
      end

      it "creates a pending invoice without raising error" do
        expect { service.call }.not_to raise_error
      end
    end
  end

  context "when we pass multiple thresholds" do
    let(:current_usage_amount_cents) { 401 }
    let(:usage_threshold) { create(:usage_threshold, plan: subscription.plan, amount_cents: 10) }
    let(:usage_threshold2) { create(:usage_threshold, plan: subscription.plan, amount_cents: 400) }

    before do
      usage_threshold
      usage_threshold2
      charge
    end

    it "ignores the flags" do
      service.call
      expect(lifetime_usage.recalculate_invoiced_usage).to eq true
      expect(lifetime_usage.recalculate_current_usage).to eq true
    end

    it "sends a webhook for the first threshold" do
      expect { service.call }.to enqueue_job(SendWebhookJob)
        .with(
          "subscription.usage_threshold_reached",
          subscription,
          usage_threshold:
        ).on_queue(webhook_queue)
    end

    it "sends a webhook for the last threshold" do
      expect { service.call }.to enqueue_job(SendWebhookJob)
        .with(
          "subscription.usage_threshold_reached",
          subscription,
          usage_threshold: usage_threshold2
        ).on_queue(webhook_queue)
    end

    it "creates an invoice for the current usage" do
      expect { service.call }.to change(Invoice, :count).by(1)
    end
  end

  context "when we pass a threshold with already progressive_billing invoices present" do
    let(:current_usage_amount_cents) { 401 }
    let(:usage_threshold) { create(:usage_threshold, plan: subscription.plan, amount_cents: 10) }
    let(:usage_threshold2) { create(:usage_threshold, plan: subscription.plan, amount_cents: 400) }
    let(:progressive_billing_invoice) do
      create(
        :invoice,
        :with_subscriptions,
        organization:,
        customer:,
        status: "finalized",
        invoice_type: :progressive_billing,
        subscriptions: [subscription]
      )
    end

    let(:progressive_billing_fee) { create(:charge_fee, amount_cents: 20, invoice: progressive_billing_invoice) }

    before do
      usage_threshold
      usage_threshold2
      progressive_billing_fee
      charge
      lifetime_usage.update! invoiced_usage_amount_cents: progressive_billing_fee.amount_cents
    end

    it "ignores the flags" do
      service.call
      expect(lifetime_usage.recalculate_invoiced_usage).to eq true
      expect(lifetime_usage.recalculate_current_usage).to eq true
    end

    it "sends a webhook for the last threshold" do
      expect { service.call }.to enqueue_job(SendWebhookJob)
        .with(
          "subscription.usage_threshold_reached",
          subscription,
          usage_threshold: usage_threshold2
        ).on_queue(webhook_queue)
    end

    it "creates an invoice for the current usage" do
      expect { service.call }.to change(Invoice, :count).by(1)
    end
  end

  context "when we pass no thresholds" do
    let(:usage_threshold) { create(:usage_threshold, plan: subscription.plan, amount_cents: 3000) }

    before do
      usage_threshold
      charge
    end

    it "ignores the flags" do
      service.call
      expect(lifetime_usage.recalculate_invoiced_usage).to eq true
      expect(lifetime_usage.recalculate_current_usage).to eq true
    end

    it "does not send a webhook for the threshold" do
      expect { service.call }.not_to enqueue_job(SendWebhookJob)
        .with(
          "subscription.usage_threshold_reached",
          subscription,
          usage_threshold:
        ).on_queue(:webhook)
    end

    it "does not create an invoice for the largest usage_threshold amount" do
      expect { service.call }.not_to change(Invoice, :count)
      expect(subscription.invoices.progressive_billing).to be_empty
    end
  end

  context "when subscription is terminated" do
    let(:subscription) { create(:subscription, :terminated, customer: customer) }

    it "does not create an invoice for the current usage" do
      expect { service.call }.not_to change(Invoice, :count)
      expect(subscription.invoices.progressive_billing).to be_empty
    end
  end
end
