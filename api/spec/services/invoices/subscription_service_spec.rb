# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::SubscriptionService do
  subject(:invoice_service) do
    described_class.new(
      subscriptions:,
      timestamp: timestamp.to_i,
      invoicing_reason:
    )
  end

  let(:organization) { create(:organization) }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:tax) { create(:tax, :applied_to_billing_entity, organization:, rate: 20, billing_entity:) }

  let(:invoicing_reason) { :subscription_periodic }

  describe "#call" do
    let(:subscription) do
      create(
        :subscription,
        plan:,
        customer:,
        subscription_at: started_at.to_date,
        started_at:,
        created_at: started_at
      )
    end
    let(:subscriptions) { [subscription] }
    let(:lifetime_usage) { create(:lifetime_usage, subscription: subscription) }

    let(:billable_metric) { create(:billable_metric, aggregation_type: "count_agg") }
    let(:timestamp) { Time.zone.now.beginning_of_month }
    let(:started_at) { Time.zone.parse("2022-10-01T00:00:00.000Z") }

    let(:plan) { create(:plan, interval: "monthly", pay_in_advance:) }
    let(:pay_in_advance) { false }

    before do
      tax
      create(:standard_charge, plan: subscription.plan, charge_model: "standard")
      lifetime_usage

      allow(SegmentTrackJob).to receive(:perform_later)
      allow(Invoices::Payments::CreateService).to receive(:call_async).and_call_original
      allow(Invoices::TransitionToFinalStatusService).to receive(:call).and_call_original
    end

    it "calls SegmentTrackJob" do
      invoice = invoice_service.call.invoice

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: "invoice_created",
        properties: {
          organization_id: invoice.organization.id,
          invoice_id: invoice.id,
          invoice_type: invoice.invoice_type
        }
      )
    end

    it "creates a payment" do
      allow(Invoices::Payments::CreateService).to receive(:call_async)

      invoice_service.call

      expect(Invoices::Payments::CreateService).to have_received(:call_async)
    end

    it "creates an invoice" do
      result = invoice_service.call

      expect(result).to be_success

      expect(result.invoice.invoice_subscriptions.first.to_datetime)
        .to match_datetime((timestamp - 1.day).end_of_day)
      expect(result.invoice.invoice_subscriptions.first.from_datetime)
        .to match_datetime((timestamp - 1.month).beginning_of_day)

      expect(result.invoice.subscriptions.first).to eq(subscription)
      expect(result.invoice.issuing_date.to_date).to eq(timestamp)
      expect(result.invoice.invoice_type).to eq("subscription")
      expect(result.invoice.payment_status).to eq("pending")
      expect(result.invoice.fees.subscription.count).to eq(1)
      expect(result.invoice.fees.charge.count).to eq(0)

      expect(result.invoice.currency).to eq("EUR")
      expect(result.invoice.fees_amount_cents).to eq(100)

      expect(result.invoice.taxes_amount_cents).to eq(20)
      expect(result.invoice.taxes_rate).to eq(20)
      expect(result.invoice.applied_taxes.count).to eq(1)

      expect(result.invoice.total_amount_cents).to eq(120)
      expect(result.invoice.version_number).to eq(4)
      expect(Invoices::TransitionToFinalStatusService).to have_received(:call).with(invoice: result.invoice)
      expect(result.invoice).to be_finalized
    end

    context "when the subscription has its own billing_entity" do
      let(:subscription_billing_entity) { create(:billing_entity, organization:) }
      let(:subscription) do
        create(
          :subscription,
          plan:,
          customer:,
          billing_entity: subscription_billing_entity,
          subscription_at: started_at.to_date,
          started_at:,
          created_at: started_at
        )
      end

      it "stamps the generated invoice with the subscription's entity" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.billing_entity_id).to eq(subscription_billing_entity.id)
      end

      it "stamps generated fees with the subscription's entity" do
        result = invoice_service.call

        expect(result.invoice.fees.subscription.first.billing_entity_id).to eq(subscription_billing_entity.id)
      end
    end

    context "when a subscription is moved between billing entities mid-lifecycle" do
      let(:eu_entity) { create(:billing_entity, organization:) }

      before { organization.update!(feature_flags: ["multi_entity_billing"]) }

      it "stamps the past invoice with the original entity, then the next billing cycle with the new one" do
        past_invoice = described_class.call(
          subscriptions:,
          timestamp: (timestamp - 1.month).to_i,
          invoicing_reason: :subscription_periodic
        ).invoice

        expect(past_invoice.billing_entity_id).to eq(billing_entity.id)

        update_result = Subscriptions::UpdateService.call(
          subscription:,
          params: {billing_entity_code: eu_entity.code}
        )
        expect(update_result).to be_success
        expect(subscription.reload.billing_entity_id).to eq(eu_entity.id)

        new_invoice = described_class.call(
          subscriptions: [subscription],
          timestamp: timestamp.to_i,
          invoicing_reason: :subscription_periodic
        ).invoice

        expect(new_invoice.billing_entity_id).to eq(eu_entity.id)
        expect(new_invoice.fees.subscription.first.billing_entity_id).to eq(eu_entity.id)
        expect(past_invoice.reload.billing_entity_id).to eq(billing_entity.id)
      end
    end

    context "when batched subscriptions resolve to different billing entities" do
      let(:other_entity) { create(:billing_entity, organization:) }
      let(:other_subscription) do
        create(
          :subscription,
          plan:,
          customer:,
          billing_entity: other_entity,
          subscription_at: started_at.to_date,
          started_at:,
          created_at: started_at
        )
      end
      let(:subscriptions) { [subscription, other_subscription] }

      it "returns a validation failure rather than producing a mixed-entity invoice" do
        result = invoice_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:billing_entity]).to eq(["mixed_billing_entities"])
      end
    end

    it_behaves_like "syncs invoice" do
      let(:service_call) { invoice_service.call }
    end

    it_behaves_like "applies invoice_custom_sections" do
      let(:service_call) { invoice_service.call }
    end

    it_behaves_like "applies invoice_custom_sections from resource" do
      let(:service_call) { invoice_service.call }
      let(:resource_with_custom_section) { subscription }
      let(:applied_section_factory) { :subscription_applied_invoice_custom_section }
      let(:resource_association_key) { :subscription }
    end

    context "with multiple subscriptions" do
      let(:subscription_2) { create(:subscription, plan:, customer:, subscription_at: started_at.to_date, started_at:, created_at: started_at) }
      let(:subscriptions) { [subscription, subscription_2] }
      let(:section_1) { create(:invoice_custom_section, organization:) }
      let(:section_2) { create(:invoice_custom_section, organization:) }

      before do
        create(:billing_entity_applied_invoice_custom_section, organization:, billing_entity:, invoice_custom_section: create(:invoice_custom_section, organization:))
      end

      context "when all subscriptions have ICS configured" do
        before do
          create(:subscription_applied_invoice_custom_section, organization:, subscription:, invoice_custom_section: section_1)
          create(:subscription_applied_invoice_custom_section, organization:, subscription: subscription_2, invoice_custom_section: section_2)
        end

        it "applies the union of all subscriptions' sections, ignoring billing entity sections" do
          result = invoice_service.call
          expect(result.invoice.applied_invoice_custom_sections.pluck(:code)).to match_array([section_1.code, section_2.code])
        end
      end

      context "when only some subscriptions have ICS configured" do
        let(:customer_section) { create(:invoice_custom_section, organization:) }

        before do
          create(:subscription_applied_invoice_custom_section, organization:, subscription:, invoice_custom_section: section_1)
          create(:customer_applied_invoice_custom_section, organization:, billing_entity:, customer:, invoice_custom_section: customer_section)
        end

        it "merges sections from configured subscriptions with customer sections" do
          result = invoice_service.call
          expect(result.invoice.applied_invoice_custom_sections.pluck(:code)).to match_array([section_1.code, customer_section.code])
        end
      end

      context "when all subscriptions have skip_invoice_custom_sections" do
        let(:subscription) { create(:subscription, plan:, customer:, subscription_at: started_at.to_date, started_at:, created_at: started_at, skip_invoice_custom_sections: true) }
        let(:subscription_2) { create(:subscription, plan:, customer:, subscription_at: started_at.to_date, started_at:, created_at: started_at, skip_invoice_custom_sections: true) }

        it "does not apply any sections" do
          result = invoice_service.call
          expect(result.invoice.applied_invoice_custom_sections).to be_empty
        end
      end
    end

    it "enqueues a SendWebhookJob" do
      expect do
        invoice_service.call
      end.to have_enqueued_job_after_commit(SendWebhookJob).with("invoice.created", Invoice)
    end

    it "produces an activity log" do
      invoice = described_class.call(subscriptions:, timestamp: timestamp.to_i, invoicing_reason:).invoice

      expect(Utils::ActivityLog).to have_produced("invoice.created").after_commit.with(invoice)
    end

    context "with billingentity resolution" do
      it "stamps the customer's billing_entity when subscription has none" do
        invoice = invoice_service.call.invoice

        expect(invoice.billing_entity).to eq(customer.billing_entity)
      end

      context "when subscription has its own billing_entity" do
        let(:other_billing_entity) { create(:billing_entity, organization:) }

        before { subscription.update!(billing_entity: other_billing_entity) }

        it "stamps the subscription's billing_entity on the invoice" do
          invoice = invoice_service.call.invoice

          expect(invoice.billing_entity).to eq(other_billing_entity)
        end
      end
    end

    it "enqueues GenerateDocumentsJob with email false" do
      expect do
        invoice_service.call
      end.to have_enqueued_job_after_commit(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
    end

    it "flags lifetime usage for refresh" do
      create(:usage_threshold, plan:)

      invoice_service.call

      expect(subscription.reload.lifetime_usage.recalculate_invoiced_usage).to be(true)
    end

    context "when there is tax provider integration" do
      let(:integration) { create(:anrok_integration, organization:) }
      let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

      before do
        integration_customer
      end

      it "creates an invoice with pending status and without applied taxes" do
        result = invoice_service.call

        expect(result).to be_success

        expect(result.invoice.subscriptions.first).to eq(subscription)
        expect(result.invoice.issuing_date.to_date).to eq(timestamp)
        expect(result.invoice.invoice_type).to eq("subscription")
        expect(result.invoice.payment_status).to eq("pending")
        expect(result.invoice.fees.subscription.count).to eq(1)
        expect(result.invoice.fees.charge.count).to eq(0)

        expect(result.invoice.currency).to eq("EUR")
        expect(result.invoice.fees_amount_cents).to eq(100)

        expect(result.invoice.taxes_amount_cents).to eq(0)
        expect(result.invoice.taxes_rate).to eq(0)
        expect(result.invoice.applied_taxes.count).to eq(0)

        expect(result.invoice.version_number).to eq(4)
        expect(result.invoice).to be_pending
      end
    end

    context "when periodic but no active subscriptions" do
      it "does not create any invoices" do
        subscription.terminated!
        expect { invoice_service.call }.not_to change(Invoice, :count)
      end
    end

    context "with lago_premium", :premium do
      context "when there is a hubspot integration" do
        let(:integration) { create(:hubspot_integration, organization:, sync_invoices:) }
        let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }

        before { integration_customer }

        context "when sync invoices is true" do
          let(:sync_invoices) { true }

          it "enqueues Integrations::Aggregator::Invoices::Hubspot::CreateJob" do
            expect do
              invoice_service.call
            end.to have_enqueued_job_after_commit(Integrations::Aggregator::Invoices::Hubspot::CreateJob)
          end
        end

        context "when sync invoices is false" do
          let(:sync_invoices) { false }

          it "does not enqueue Integrations::Aggregator::Invoices::Hubspot::CreateJob" do
            expect do
              invoice_service.call
            end.not_to have_enqueued_job(Integrations::Aggregator::Invoices::Hubspot::CreateJob)
          end
        end
      end

      context "when there is a netsuite integration" do
        let(:integration) { create(:netsuite_integration, organization:, sync_invoices:) }
        let(:integration_customer) { create(:netsuite_customer, integration:, customer:) }

        before { integration_customer }

        context "when sync invoices is true" do
          let(:sync_invoices) { true }

          it "enqueues Integrations::Aggregator::Invoices::CreateJob" do
            expect do
              invoice_service.call
            end.to have_enqueued_job_after_commit(Integrations::Aggregator::Invoices::CreateJob)
          end
        end

        context "when sync invoices is false" do
          let(:sync_invoices) { false }

          it "does not enqueue Integrations::Aggregator::Invoices::CreateJob" do
            expect do
              invoice_service.call
            end.not_to have_enqueued_job(Integrations::Aggregator::Invoices::CreateJob)
          end
        end
      end

      it "enqueues GenerateDocumentsJob with email true" do
        expect do
          invoice_service.call
        end.to have_enqueued_job_after_commit(Invoices::GenerateDocumentsJob).with(hash_including(notify: true))
      end

      context "when organization does not have right email settings" do
        before { customer.billing_entity.update!(email_settings: []) }

        it "enqueues GenerateDocumentsJob with email false" do
          expect do
            invoice_service.call
          end.to have_enqueued_job_after_commit(Invoices::GenerateDocumentsJob).with(hash_including(notify: false))
        end
      end
    end

    context "with customer timezone" do
      before { subscription.customer.update!(timezone: "America/Los_Angeles", invoice_grace_period: 3) }

      let(:timestamp) { DateTime.parse("2022-11-25 01:00:00") }

      it "assigns the issuing date in the customer timezone" do
        result = invoice_service.call

        expect(result.invoice.issuing_date.to_s).to eq("2022-11-27")
      end
    end

    context "with applicable grace period" do
      before do
        subscription.customer.update!(invoice_grace_period: 3)
        create(:wallet, customer: subscription.customer)
      end

      it "does not track any invoice creation on segment" do
        invoice_service.call
        expect(SegmentTrackJob).not_to have_received(:perform_later)
      end

      it "does not create any payment" do
        invoice_service.call
        expect(Invoices::Payments::CreateService).not_to have_received(:call_async)
      end

      it "creates an invoice as draft" do
        result = invoice_service.call
        expect(result).to be_success
        expect(result.invoice).to be_draft
      end

      it "enqueues a SendWebhookJob" do
        expect do
          invoice_service.call
        end.to have_enqueued_job_after_commit(SendWebhookJob).with("invoice.drafted", Invoice)
      end

      it "produces an activity log" do
        invoice = described_class.call(subscriptions:, timestamp: timestamp.to_i, invoicing_reason:).invoice

        expect(Utils::ActivityLog).to have_produced("invoice.drafted").after_commit.with(invoice)
      end

      it "enqueues a SendWebhookJob for invoice.ready_to_finalize" do
        expect do
          invoice_service.call
        end.to have_enqueued_job_after_commit(SendWebhookJob).with("invoice.ready_to_finalize", Invoice)
      end

      it "produces an activity log for invoice.ready_to_finalize" do
        invoice = described_class.call(subscriptions:, timestamp: timestamp.to_i, invoicing_reason:).invoice

        expect(Utils::ActivityLog).to have_produced("invoice.ready_to_finalize").after_commit.with(invoice)
      end

      it "does not flag lifetime usage for refresh" do
        invoice_service.call

        expect(lifetime_usage.reload.recalculate_invoiced_usage).to be(false)
      end

      it "marks customer as awaiting wallet refresh" do
        expect { invoice_service.call }.to change { customer.reload.awaiting_wallet_refresh }.from(false).to(true)
      end

      context "with keep_anchor as issuing_date adjustment" do
        before do
          customer.update!(subscription_invoice_issuing_date_adjustment: "keep_anchor")
        end

        it "creates an invoice as draft" do
          result = invoice_service.call
          expect(result).to be_success
          expect(result.invoice).to be_draft
        end
      end

      context "when the invoice ends with pending taxes" do
        let(:integration) { create(:anrok_integration, organization:) }
        let(:integration_customer) { create(:anrok_customer, integration:, customer:) }

        before { integration_customer }

        it "creates a draft invoice with tax_status pending" do
          result = invoice_service.call

          expect(result).to be_success
          expect(result.invoice).to be_draft
          expect(result.invoice).to be_tax_pending
        end

        it "enqueues a SendWebhookJob for invoice.drafted" do
          expect do
            invoice_service.call
          end.to have_enqueued_job_after_commit(SendWebhookJob).with("invoice.drafted", Invoice)
        end

        it "does not enqueue a SendWebhookJob for invoice.ready_to_finalize" do
          expect do
            invoice_service.call
          end.not_to have_enqueued_job(SendWebhookJob).with("invoice.ready_to_finalize", Invoice)
        end

        it "does not produce an activity log for invoice.ready_to_finalize" do
          invoice_service.call

          expect(Utils::ActivityLog).not_to have_produced("invoice.ready_to_finalize")
        end
      end
    end

    context "when invoice already exists" do
      let(:timestamp) { Time.zone.parse("2023-10-01T00:00:00.000Z") }

      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          invoice: old_invoice,
          subscription:,
          from_datetime: Time.zone.parse("2023-09-01T00:00:00.000Z"),
          to_datetime: Time.zone.parse("2023-09-30T23:59:59.999Z").end_of_day,
          charges_from_datetime: Time.zone.parse("2023-09-01T00:00:00.000Z"),
          charges_to_datetime: Time.zone.parse("2023-09-30T23:59:59.999Z").end_of_day,
          recurring: invoicing_reason.to_sym == :subscription_periodic,
          invoicing_reason:
        )
      end

      let(:old_invoice) do
        create(
          :invoice,
          created_at: timestamp + 1.second,
          customer: subscription.customer
        )
      end

      before { invoice_subscription }

      it "does not raise an error" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice).to be_nil
      end
    end

    context "when skip zero invoices is set" do
      before do
        customer.update(finalize_zero_amount_invoice: :skip)
      end

      context "when invoice total amount is not 0" do
        it "creates an invoice in :finalized status" do
          result = invoice_service.call
          expect(result.invoice.status).to eq("finalized")
          expect(result.invoice.number).not_to include("DRAFT")
        end
      end

      context "when invoice total amount is 0" do
        let(:plan) { create(:plan, interval: "monthly", pay_in_advance:, amount_cents: 0) }

        before do
          plan
        end

        it "creates an invoice in :closed status" do
          result = invoice_service.call
          expect(result.invoice.status).to eq("closed")
          expect(result.invoice.number).to include("DRAFT")
        end

        context "when billing entity has grace period" do
          let(:billing_entity) { create(:billing_entity, organization:, invoice_grace_period: 30) }

          it "creates an invoice in :draft status" do
            result = invoice_service.call
            expect(result.invoice.status).to eq("draft")
          end
        end
      end
    end

    context "when revenue_analytics is set", :premium do
      before do
        organization.update!(premium_integrations: %w[revenue_analytics])
      end

      it "enqueues DailyUsages::FillFromInvoiceJob with email false" do
        expect { invoice_service.call }
          .to have_enqueued_job_after_commit(DailyUsages::FillFromInvoiceJob)
          .with(invoice: an_instance_of(Invoice), subscriptions: [subscription])
      end

      context "when subscription is terminating" do
        let(:invoicing_reason) { :subscription_terminating }

        it "enqueues DailyUsages::FillFromInvoiceJob with email false" do
          expect { invoice_service.call }
            .to have_enqueued_job_after_commit(DailyUsages::FillFromInvoiceJob)
            .with(invoice: an_instance_of(Invoice), subscriptions: [subscription])
        end
      end
    end

    context "when creating invoice for partner" do
      let(:customer) { create(:customer, :with_salesforce_integration, :with_hubspot_integration, organization:, account_type: "partner") }
      let(:salesforce_service) { instance_double(Integrations::Aggregator::Invoices::CreateService) }
      let(:hubspot_service) { instance_double(Integrations::Aggregator::Invoices::Hubspot::CreateService) }
      let(:result) { BaseService::Result.new }

      before do
        allow(Integrations::Aggregator::Invoices::CreateService).to receive(:new).and_return(salesforce_service)
        allow(salesforce_service).to receive(:call).and_return(result)
        allow(Integrations::Aggregator::Invoices::Hubspot::CreateService).to receive(:new).and_return(hubspot_service)
        allow(hubspot_service).to receive(:call).and_return(result)
      end

      it "doesn't send update to integrations" do
        invoice_service.call

        expect(Integrations::Aggregator::Invoices::CreateService).not_to have_received(:new)
        expect(Integrations::Aggregator::Invoices::Hubspot::CreateService).not_to have_received(:new)
      end
    end

    context "when plan has pay in advance fixed charges" do
      let(:plan) { create(:plan, interval: "monthly", pay_in_advance: true, organization:) }
      let(:add_on) { create(:add_on, organization:) }
      let(:fixed_charge) { create(:fixed_charge, plan:, add_on:, pay_in_advance: true, properties: {amount: "100"}) }

      let(:started_at) { Time.zone.now.beginning_of_month }
      let(:timestamp) { started_at }
      let(:invoicing_reason) { :subscription_starting }

      let(:subscription) do
        create(
          :subscription,
          plan:,
          customer:,
          subscription_at: started_at.to_date,
          started_at:,
          created_at: started_at
        )
      end

      let(:fixed_charge_event) do
        create(
          :fixed_charge_event,
          subscription:,
          fixed_charge:,
          units: fixed_charge.units,
          timestamp: started_at
        )
      end

      before do
        fixed_charge
        fixed_charge_event
      end

      it "creates fixed charge fees" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice.fees.subscription.count).to eq(1)
        expect(result.invoice.fees.fixed_charge.count).to eq(1)
      end
    end

    context "when subscription trial period ends with pay in advance fixed charges already billed" do
      let(:trial_period) { 15 }
      let(:plan) { create(:plan, interval: "monthly", pay_in_advance: true, trial_period:, organization:) }
      let(:add_on) { create(:add_on, organization:) }
      let(:fixed_charge) { create(:fixed_charge, plan:, add_on:, pay_in_advance: true, properties: {amount: "100"}) }

      let(:started_at) { Time.zone.parse("2024-01-01T00:00:00Z") }
      let(:trial_end_timestamp) { started_at + trial_period.days }
      let(:timestamp) { trial_end_timestamp }
      let(:invoicing_reason) { :subscription_starting }

      let(:subscription) do
        create(
          :subscription,
          plan:,
          customer:,
          subscription_at: started_at.to_date,
          started_at:,
          created_at: started_at
        )
      end

      let(:billing_period_start) { started_at.beginning_of_month }
      let(:billing_period_end) { started_at.end_of_month }

      # Simulate the invoice created on Day 1 for pay in advance fixed charges
      let(:existing_invoice) do
        create(
          :invoice,
          customer:,
          organization:,
          invoice_type: :subscription,
          status: :finalized,
          created_at: started_at
        )
      end

      let(:existing_invoice_subscription) do
        create(
          :invoice_subscription,
          invoice: existing_invoice,
          subscription:,
          invoicing_reason: :in_advance_charge,
          timestamp: started_at
        )
      end

      # The fixed charge event created when subscription started (Day 1)
      let(:fixed_charge_event) do
        create(
          :fixed_charge_event,
          subscription:,
          fixed_charge:,
          units: fixed_charge.units,
          timestamp: started_at
        )
      end

      # The fixed charge fee created on Day 1
      let(:existing_fixed_charge_fee) do
        create(
          :fixed_charge_fee,
          invoice: existing_invoice,
          subscription:,
          fixed_charge:,
          amount_cents: 10000,
          properties: {
            "timestamp" => started_at.iso8601,
            "fixed_charges_from_datetime" => billing_period_start.iso8601,
            "fixed_charges_to_datetime" => billing_period_end.iso8601
          }
        )
      end

      before do
        fixed_charge
        fixed_charge_event
        existing_invoice_subscription
        existing_fixed_charge_fee
      end

      around do |example|
        travel_to(trial_end_timestamp) { example.run }
      end

      it "does not create a duplicate fixed charge fee for the same billing period" do
        result = invoice_service.call

        expect(result).to be_success

        # Subscription fee should be created (plan is pay_in_advance, trial ending)
        expect(result.invoice.fees.subscription.count).to eq(1)

        # Fixed charge fee should NOT be created again since it was already billed on Day 1
        # for the same billing period (Jan 1 - Jan 31)
        expect(result.invoice.fees.fixed_charge.count).to eq(0)
      end
    end

    context "when subscription is gated" do
      let(:invoicing_reason) { :subscription_starting }
      let(:pay_in_advance) { true }
      let(:subscription) do
        create(:subscription, :incomplete, :with_activation_rules,
          activation_rules_config: [{type: "payment", timeout_hours: 48, status: "pending"}],
          plan:, customer:, organization: customer.organization,
          subscription_at: started_at.to_date, started_at:, created_at: started_at)
      end

      it "creates an open invoice" do
        result = invoice_service.call

        expect(result).to be_success
        expect(result.invoice).to be_open
      end

      it "skips grace period" do
        result = invoice_service.call

        expect(result.invoice.issuing_date.to_s).to eq(Time.zone.at(timestamp).to_date.to_s)
      end

      it "does not send invoice.created webhook" do
        invoice_service.call

        expect(SendWebhookJob).not_to have_been_enqueued.with("invoice.created", anything)
      end

      it "does not generate documents" do
        invoice_service.call

        expect(Invoices::GenerateDocumentsJob).not_to have_been_enqueued
      end

      it "triggers payment" do
        invoice_service.call

        expect(Invoices::Payments::CreateService).to have_received(:call_async)
      end

      context "when invoice total is zero" do
        let(:plan) { create(:plan, interval: "monthly", pay_in_advance: true, amount_cents: 0) }
        let(:rule) { subscription.activation_rules.payment.sole }

        it "marks the payment activation rule as satisfied" do
          invoice_service.call

          expect(rule.reload).to be_satisfied
        end

        it "activates the subscription" do
          invoice_service.call

          expect(subscription.reload).to be_active
        end
      end

      context "when tax is pending" do
        let(:integration) { create(:anrok_integration, organization:) }
        let(:integration_customer) { create(:anrok_customer, integration:, customer:) }
        let(:rule) { subscription.activation_rules.payment.sole }

        before { integration_customer }

        it "does not fire the zero-amount activation shortcut" do
          invoice_service.call

          expect(rule.reload).to be_pending
          expect(subscription.reload).to be_incomplete
        end

        it "keeps the invoice open with tax_status pending" do
          result = invoice_service.call

          expect(result.invoice).to be_open
          expect(result.invoice.tax_status).to eq("pending")
        end
      end
    end

    context "when an error occurs" do
      context "with a stale object error" do
        it "propagates the error" do
          allow_any_instance_of(Credits::AppliedPrepaidCreditsService) # rubocop:disable RSpec/AnyInstance
            .to receive(:call).and_raise(ActiveRecord::StaleObjectError)

          expect { invoice_service.call }.to raise_error(ActiveRecord::StaleObjectError)
        end
      end

      context "with a failed to acquire lock error" do
        it "propagates the error" do
          allow_any_instance_of(Credits::AppliedPrepaidCreditsService) # rubocop:disable RSpec/AnyInstance
            .to receive(:call).and_raise(Customers::FailedToAcquireLock)

          expect { invoice_service.call }.to raise_error(Customers::FailedToAcquireLock)
        end
      end
    end
  end
end
