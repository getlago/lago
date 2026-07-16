# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ActivateService do
  subject(:result) { described_class.call(subscription:, timestamp:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, :pending, organization:, customer:, plan:, subscription_at: Time.current) }
  let(:timestamp) { Time.current }

  context "when subscription is pending without activation rules" do
    it "activates the subscription" do
      freeze_time do
        expect(result.subscription).to be_active
        expect(result.subscription.started_at).to eq(Time.current)
        expect(result.subscription.activated_at).to eq(Time.current)
      end
    end

    it "sends a subscription.started webhook" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", subscription)
    end

    it "produces a subscription.started activity log" do
      result

      expect(Utils::ActivityLog).to have_produced("subscription.started").with(subscription)
    end

    it "does not enqueue billing jobs" do
      result

      expect(BillSubscriptionJob).not_to have_been_enqueued
      expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
    end

    it "does not enqueue the fixed-charge delta job" do
      result

      expect(Subscriptions::ActivationRules::BillFixedChargesDeltaJob).not_to have_been_enqueued
    end

    it "does not enqueue the missed-periods job" do
      result

      expect(Subscriptions::ActivationRules::BillMissedPeriodsJob).not_to have_been_enqueued
    end

    context "when subscription has fixed charges" do
      let(:add_on) { create(:add_on, organization:) }

      before { create(:fixed_charge, plan:, add_on:) }

      it "emits fixed charge events" do
        expect { result }.to change(FixedChargeEvent, :count).by(1)
      end
    end

    context "when subscription should sync with hubspot" do
      let(:customer) { create(:customer, :with_hubspot_integration, organization:) }

      it "enqueues hubspot create job" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob)
          .to have_been_enqueued.with(subscription:)
      end

      it "does not enqueue hubspot update job" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).not_to have_been_enqueued
      end
    end

    context "when plan is pay in advance and not in trial" do
      let(:plan) { create(:plan, organization:, pay_in_advance: true) }

      it "enqueues BillSubscriptionJob with skip_charges true" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], anything, invoicing_reason: :subscription_starting, skip_charges: true)
      end

      it "does not enqueue CreatePayInAdvanceFixedChargesJob" do
        result

        expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
      end
    end

    context "when plan is pay in advance with pay-in-advance fixed charges" do
      let(:plan) { create(:plan, organization:, pay_in_advance: true) }
      let(:add_on) { create(:add_on, organization:) }

      before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

      it "enqueues BillSubscriptionJob but not CreatePayInAdvanceFixedChargesJob" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
        expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
      end
    end

    context "when plan is pay in arrears with pay-in-advance fixed charges" do
      let(:plan) { create(:plan, organization:, pay_in_advance: false) }
      let(:add_on) { create(:add_on, organization:) }

      before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

      it "enqueues CreatePayInAdvanceFixedChargesJob" do
        result

        expect(Invoices::CreatePayInAdvanceFixedChargesJob).to have_been_enqueued
      end

      it "does not enqueue BillSubscriptionJob" do
        result

        expect(BillSubscriptionJob).not_to have_been_enqueued
      end
    end

    context "when plan is pay in arrears with non-pay-in-advance fixed charges" do
      let(:plan) { create(:plan, organization:, pay_in_advance: false) }
      let(:add_on) { create(:add_on, organization:) }

      before { create(:fixed_charge, plan:, add_on:, pay_in_advance: false) }

      it "does not enqueue any billing job" do
        result

        expect(BillSubscriptionJob).not_to have_been_enqueued
        expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
      end
    end

    context "when plan is pay in advance with trial period" do
      let(:plan) { create(:plan, organization:, pay_in_advance: true, trial_period: 30) }

      it "does not enqueue BillSubscriptionJob" do
        result

        expect(BillSubscriptionJob).not_to have_been_enqueued
      end

      context "when plan has pay-in-advance fixed charges" do
        let(:add_on) { create(:add_on, organization:) }

        before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

        it "enqueues CreatePayInAdvanceFixedChargesJob" do
          result

          expect(Invoices::CreatePayInAdvanceFixedChargesJob).to have_been_enqueued
        end

        it "does not enqueue BillSubscriptionJob" do
          result

          expect(BillSubscriptionJob).not_to have_been_enqueued
        end
      end
    end
  end

  context "when subscription is pending with activation rules (payment, pay-in-advance plan)" do
    let(:plan) { create(:plan, organization:, pay_in_advance: true) }
    let(:subscription) do
      create(:subscription, :pending, :with_activation_rules,
        activation_rules_config: [{type: "payment", timeout_hours: 48}],
        organization:, customer:, plan:, subscription_at: Time.current)
    end

    it "evaluates rules and marks the subscription as incomplete" do
      expect(result.subscription).to be_incomplete
      expect(result.subscription.started_at).to be_present
      expect(subscription.activation_rules.sole).to be_pending
    end

    it "emits fixed charge events" do
      add_on = create(:add_on, organization:)
      create(:fixed_charge, plan:, add_on:)

      expect { result }.to change(FixedChargeEvent, :count).by(1)
    end

    it "sends a subscription.incomplete webhook" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.incomplete", subscription)
    end

    it "produces a subscription.incomplete activity log" do
      result

      expect(Utils::ActivityLog).to have_produced("subscription.incomplete").with(subscription)
    end

    context "when the customer should sync with hubspot" do
      let(:customer) { create(:customer, :with_hubspot_integration, organization:) }

      it "does not sync the incomplete subscription" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob).not_to have_been_enqueued
        expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).not_to have_been_enqueued
      end
    end

    it "enqueues BillSubscriptionJob with skip_charges" do
      result

      expect(BillSubscriptionJob).to have_been_enqueued
        .with([subscription], anything, invoicing_reason: :subscription_starting, skip_charges: true)
    end

    context "when plan is pay in arrears with pay-in-advance fixed charges" do
      let(:plan) { create(:plan, organization:, pay_in_advance: false) }
      let(:add_on) { create(:add_on, organization:) }

      before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

      it "enqueues CreatePayInAdvanceFixedChargesJob" do
        result

        expect(Invoices::CreatePayInAdvanceFixedChargesJob).to have_been_enqueued
      end

      it "does not enqueue BillSubscriptionJob" do
        result

        expect(BillSubscriptionJob).not_to have_been_enqueued
      end
    end

    context "when plan is pay in advance with trial period" do
      let(:plan) { create(:plan, organization:, pay_in_advance: true, trial_period: 30) }

      it "does not enqueue BillSubscriptionJob" do
        result

        expect(BillSubscriptionJob).not_to have_been_enqueued
      end

      context "when plan has pay-in-advance fixed charges" do
        let(:add_on) { create(:add_on, organization:) }

        before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

        it "enqueues CreatePayInAdvanceFixedChargesJob" do
          result

          expect(Invoices::CreatePayInAdvanceFixedChargesJob).to have_been_enqueued
        end
      end
    end
  end

  context "when subscription is pending with activation rules that evaluate to not_applicable" do
    let(:plan) { create(:plan, organization:, pay_in_advance: false) }
    let(:subscription) do
      create(:subscription, :pending, :with_activation_rules,
        activation_rules_config: [{type: "payment", timeout_hours: 48}],
        organization:, customer:, plan:, subscription_at: Time.current)
    end

    it "evaluates rules as not_applicable and activates normally" do
      expect(result.subscription).to be_active
      expect(subscription.activation_rules.sole).to be_not_applicable
    end

    it "sends a subscription.started webhook" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", subscription)
    end
  end

  context "when subscription is incomplete with satisfied payment rule (post-payment activation)" do
    let(:plan) { create(:plan, organization:, pay_in_advance: true) }
    let(:subscription) do
      create(:subscription, :incomplete, :with_activation_rules,
        activation_rules_config: [{type: "payment", timeout_hours: 48, status: "satisfied"}],
        organization:, customer:, plan:)
    end

    it "activates the subscription" do
      freeze_time do
        expect(result.subscription).to be_active
        expect(result.subscription.activated_at).to eq(Time.current)
      end
    end

    it "sends a subscription.started webhook" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", subscription)
    end

    it "produces a subscription.started activity log" do
      result

      expect(Utils::ActivityLog).to have_produced("subscription.started").with(subscription)
    end

    it "does not enqueue billing jobs (already billed during gating)" do
      result

      expect(BillSubscriptionJob).not_to have_been_enqueued
      expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
    end

    it "does not emit fixed charge events (already emitted during gating)" do
      add_on = create(:add_on, organization:)
      create(:fixed_charge, plan:, add_on:)

      expect { result }.not_to change(FixedChargeEvent, :count)
    end

    it "enqueues the fixed-charge delta job" do
      result

      expect(Subscriptions::ActivationRules::BillFixedChargesDeltaJob).to have_been_enqueued.with(subscription)
    end

    it "enqueues the missed-periods job" do
      result

      expect(Subscriptions::ActivationRules::BillMissedPeriodsJob).to have_been_enqueued.with(subscription)
    end

    context "when subscription should sync with hubspot" do
      let(:customer) { create(:customer, :with_hubspot_integration, organization:) }

      it "enqueues hubspot create job" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob)
          .to have_been_enqueued.with(subscription:)
      end

      it "does not enqueue hubspot update job" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).not_to have_been_enqueued
      end
    end

    context "when subscription comes from an upgrade" do
      let(:customer) { create(:customer, :with_hubspot_integration, organization:) }
      let(:previous_plan) { create(:plan, organization:, amount_cents: 50) }
      let(:plan) { create(:plan, organization:, amount_cents: 100, pay_in_advance: true) }
      let(:previous_subscription) do
        create(:subscription, organization:, customer:, plan: previous_plan,
          status: :active, started_at: 1.day.ago, subscription_at: 1.day.ago)
      end
      let(:subscription) do
        create(:subscription, :incomplete, :with_activation_rules,
          activation_rules_config: [{type: "payment", timeout_hours: 48, status: "satisfied"}],
          organization:, customer:, plan:, previous_subscription:,
          subscription_at: Time.current)
      end

      it "terminates the previous subscription" do
        result

        expect(previous_subscription.reload).to be_terminated
      end

      it "marks the new subscription as active" do
        freeze_time do
          expect(result.subscription).to be_active
          expect(result.subscription.activated_at).to eq(Time.current)
        end
      end

      it "sends a subscription.started webhook for the new subscription" do
        result

        expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", subscription)
      end

      it "produces a subscription.started activity log" do
        result

        expect(Utils::ActivityLog).to have_produced("subscription.started").with(subscription)
      end

      it "enqueues BillSubscriptionJob for the previous subscription only with :upgrading" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([previous_subscription], anything, invoicing_reason: :upgrading)
      end

      it "enqueues BillNonInvoiceableFeesJob for the previous subscription only" do
        result

        expect(BillNonInvoiceableFeesJob).to have_been_enqueued.with([previous_subscription], anything)
      end

      it "enqueues Hubspot::CreateJob for the new subscription" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob)
          .to have_been_enqueued.with(subscription: subscription)
      end

      it "enqueues the fixed-charge delta job" do
        result

        expect(Subscriptions::ActivationRules::BillFixedChargesDeltaJob).to have_been_enqueued.with(subscription)
      end

      it "does not enqueue the missed-periods job" do
        result

        expect(Subscriptions::ActivationRules::BillMissedPeriodsJob).not_to have_been_enqueued
      end

      context "when subscription should not sync with hubspot" do
        let(:customer) { create(:customer, organization:) }

        it "does not enqueue Hubspot::CreateJob" do
          result

          expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob).not_to have_been_enqueued
        end
      end
    end

    context "when subscription comes from a downgrade" do
      let(:customer) { create(:customer, :with_hubspot_integration, organization:) }
      let(:previous_plan) { create(:plan, organization:, amount_cents: 100) }
      let(:plan) { create(:plan, organization:, amount_cents: 50, pay_in_advance: true) }
      let(:previous_subscription) do
        create(:subscription, organization:, customer:, plan: previous_plan,
          status: :active, started_at: 1.month.ago, subscription_at: 1.month.ago)
      end
      let(:subscription) do
        create(:subscription, :incomplete, :with_activation_rules,
          activation_rules_config: [{type: "payment", timeout_hours: 48, status: "satisfied"}],
          organization:, customer:, plan:, previous_subscription:,
          subscription_at: Time.current)
      end

      it "terminates the previous subscription" do
        result

        expect(previous_subscription.reload).to be_terminated
      end

      it "marks the new subscription as active" do
        freeze_time do
          expect(result.subscription).to be_active
          expect(result.subscription.activated_at).to eq(Time.current)
        end
      end

      it "sends a subscription.terminated webhook for the previous subscription" do
        result

        expect(SendWebhookJob).to have_been_enqueued.with("subscription.terminated", previous_subscription)
      end

      it "produces a subscription.terminated activity log for the previous subscription" do
        result

        expect(Utils::ActivityLog).to have_produced("subscription.terminated").with(previous_subscription)
      end

      it "sends a subscription.started webhook for the new subscription" do
        result

        expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", subscription)
      end

      it "produces a subscription.started activity log for the new subscription" do
        result

        expect(Utils::ActivityLog).to have_produced("subscription.started").with(subscription)
      end

      it "does not emit fixed charge events (already emitted during gating)" do
        add_on = create(:add_on, organization:)
        create(:fixed_charge, plan:, add_on:)

        expect { result }.not_to change(FixedChargeEvent, :count)
      end

      it "enqueues BillSubscriptionJob for the previous subscription only with :upgrading" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([previous_subscription], anything, invoicing_reason: :upgrading)
      end

      it "enqueues BillNonInvoiceableFeesJob for the previous subscription only" do
        result

        expect(BillNonInvoiceableFeesJob).to have_been_enqueued.with([previous_subscription], anything)
      end

      it "enqueues Hubspot::UpdateJob for the previous subscription" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob)
          .to have_been_enqueued.with(subscription: previous_subscription)
      end

      it "does not enqueue the missed-periods job" do
        result

        expect(Subscriptions::ActivationRules::BillMissedPeriodsJob).not_to have_been_enqueued
      end

      it "enqueues Hubspot::CreateJob for the new subscription" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob)
          .to have_been_enqueued.with(subscription:)
      end

      it "enqueues the fixed-charge delta job" do
        result

        expect(Subscriptions::ActivationRules::BillFixedChargesDeltaJob).to have_been_enqueued.with(subscription)
      end

      context "when subscription should not sync with hubspot" do
        let(:customer) { create(:customer, organization:) }

        it "does not enqueue Hubspot::CreateJob" do
          result

          expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob).not_to have_been_enqueued
        end
      end
    end
  end

  context "when subscription is incomplete with no payment rules (future non-payment rule resolved)" do
    let(:plan) { create(:plan, organization:, pay_in_advance: true) }
    let(:subscription) { create(:subscription, :incomplete, organization:, customer:, plan:) }

    it "activates and bills the subscription" do
      result

      expect(result.subscription).to be_active
      expect(BillSubscriptionJob).to have_been_enqueued
    end

    it "does not enqueue the fixed-charge delta job" do
      result

      expect(Subscriptions::ActivationRules::BillFixedChargesDeltaJob).not_to have_been_enqueued
    end

    it "does not enqueue the missed-periods job" do
      result

      expect(Subscriptions::ActivationRules::BillMissedPeriodsJob).not_to have_been_enqueued
    end
  end

  context "when subscription is incomplete with a failed payment rule" do
    let(:plan) { create(:plan, organization:, pay_in_advance: true) }
    let(:subscription) do
      create(:subscription, :incomplete, :with_activation_rules,
        activation_rules_config: [{type: :payment, timeout_hours: 48, status: :failed}],
        organization:, customer:, plan:)
    end

    it "does not activate the subscription" do
      result

      expect(subscription.reload).to be_incomplete
      expect(SendWebhookJob).not_to have_been_enqueued
      expect(BillSubscriptionJob).not_to have_been_enqueued
    end
  end

  context "when subscription is already active" do
    let(:subscription) { create(:subscription, organization:, customer:, plan:) }

    it "returns early without changes" do
      result

      expect(subscription.reload).to be_active
      expect(SendWebhookJob).not_to have_been_enqueued
      expect(BillSubscriptionJob).not_to have_been_enqueued
      expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
    end
  end

  context "when subscription is already gated (incomplete with pending rules)" do
    let(:subscription) do
      create(:subscription, :incomplete, :with_activation_rules,
        activation_rules_config: [{type: "payment", timeout_hours: 48, status: "pending"}],
        organization:, customer:, plan:)
    end

    it "returns early without changes" do
      result

      expect(subscription.reload).to be_incomplete
      expect(SendWebhookJob).not_to have_been_enqueued
    end
  end

  context "when subscription comes from an upgrade" do
    let(:customer) { create(:customer, :with_hubspot_integration, organization:) }
    let(:previous_plan) { create(:plan, organization:, amount_cents: 50) }
    let(:plan) { create(:plan, organization:, amount_cents: 100) }
    let(:previous_subscription) do
      create(
        :subscription,
        organization:,
        customer:,
        plan: previous_plan,
        status: :active,
        started_at: 1.day.ago,
        subscription_at: 1.day.ago
      )
    end
    let(:subscription) do
      create(
        :subscription,
        :pending,
        organization:,
        customer:,
        plan:,
        previous_subscription:,
        subscription_at: Time.current
      )
    end

    it "terminates the previous subscription" do
      result

      expect(previous_subscription.reload).to be_terminated
    end

    it "marks the new subscription as active" do
      freeze_time do
        expect(result.subscription).to be_active
        expect(result.subscription.started_at).to eq(Time.current)
      end
    end

    it "enqueues Hubspot::CreateJob for the new subscription" do
      result

      expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob)
        .to have_been_enqueued.with(subscription: subscription)
    end

    context "when subscription should not sync with hubspot" do
      let(:customer) { create(:customer, organization:) }

      it "does not enqueue Hubspot::CreateJob" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob).not_to have_been_enqueued
      end
    end

    it "sends a subscription.started webhook for the new subscription" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", subscription)
    end

    it "produces a subscription.started activity log" do
      result

      expect(Utils::ActivityLog).to have_produced("subscription.started").with(subscription)
    end

    it "enqueues BillSubscriptionJob with invoicing_reason :upgrading" do
      result

      expect(BillSubscriptionJob).to have_been_enqueued
        .with([previous_subscription], anything, invoicing_reason: :upgrading)
    end

    it "enqueues BillNonInvoiceableFeesJob for the previous subscription only" do
      result

      expect(BillNonInvoiceableFeesJob).to have_been_enqueued.with([previous_subscription], anything)
    end

    context "when the new plan is pay in advance" do
      let(:plan) { create(:plan, organization:, amount_cents: 100, pay_in_advance: true) }

      it "includes both previous and new subscription in the upgrade bill" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([previous_subscription, subscription], anything, invoicing_reason: :upgrading)
      end

      it "includes both previous and new subscription in BillNonInvoiceableFeesJob" do
        result

        expect(BillNonInvoiceableFeesJob).to have_been_enqueued
          .with([previous_subscription, subscription], anything)
      end
    end

    context "when activation_rules gate the new subscription" do
      let(:plan) { create(:plan, organization:, amount_cents: 100, pay_in_advance: true) }
      let(:subscription) do
        create(
          :subscription,
          :pending,
          :with_activation_rules,
          organization:,
          customer:,
          plan:,
          previous_subscription:,
          subscription_at: Time.current
        )
      end

      it "marks the new subscription as incomplete" do
        expect(result.subscription).to be_incomplete
      end

      it "does not terminate the previous subscription" do
        result

        expect(previous_subscription.reload).to be_active
      end

      it "sends a subscription.incomplete webhook" do
        result

        expect(SendWebhookJob).to have_been_enqueued.with("subscription.incomplete", subscription)
      end

      it "enqueues BillSubscriptionJob for the incomplete subscription with skip_charges and :upgrading" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], anything, invoicing_reason: :upgrading, skip_charges: true)
      end
    end

    context "when the subscription is incomplete with no payment rules" do
      let(:plan) { create(:plan, organization:, amount_cents: 100, pay_in_advance: true) }
      let(:subscription) do
        create(
          :subscription,
          :incomplete,
          organization:,
          customer:,
          plan:,
          previous_subscription:,
          subscription_at: Time.current
        )
      end

      it "includes the new subscription in the upgrade bill (never billed during gating)" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([previous_subscription, subscription], anything, invoicing_reason: :upgrading)
      end
    end
  end

  context "when subscription comes from a downgrade" do
    let(:customer) { create(:customer, :with_hubspot_integration, organization:) }
    let(:previous_plan) { create(:plan, organization:, amount_cents: 100) }
    let(:plan) { create(:plan, organization:, amount_cents: 50) }
    let(:previous_subscription) do
      create(
        :subscription,
        organization:,
        customer:,
        plan: previous_plan,
        status: :active,
        started_at: 1.month.ago,
        subscription_at: 1.month.ago
      )
    end
    let(:subscription) do
      create(
        :subscription,
        :pending,
        organization:,
        customer:,
        plan:,
        previous_subscription:,
        subscription_at: Time.current
      )
    end

    it "terminates the previous subscription at the given timestamp" do
      freeze_time do
        result

        expect(previous_subscription.reload).to be_terminated
        expect(previous_subscription.terminated_at).to eq(timestamp)
      end
    end

    it "marks the new subscription as active at the given timestamp" do
      freeze_time do
        expect(result.subscription).to be_active
        expect(result.subscription.started_at).to eq(timestamp)
      end
    end

    it "sends a subscription.terminated webhook for the previous subscription" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.terminated", previous_subscription)
    end

    it "produces a subscription.terminated activity log for the previous subscription" do
      result

      expect(Utils::ActivityLog).to have_produced("subscription.terminated").with(previous_subscription)
    end

    it "sends a subscription.started webhook for the new subscription" do
      result

      expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", subscription)
    end

    it "produces a subscription.started activity log for the new subscription" do
      result

      expect(Utils::ActivityLog).to have_produced("subscription.started").with(subscription)
    end

    it "enqueues Hubspot::UpdateJob for the previous subscription" do
      result

      expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob)
        .to have_been_enqueued.with(subscription: previous_subscription)
    end

    it "enqueues Hubspot::CreateJob for the new subscription" do
      result

      expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob)
        .to have_been_enqueued.with(subscription:)
    end

    context "when subscription should not sync with hubspot" do
      let(:customer) { create(:customer, organization:) }

      it "does not enqueue Hubspot::UpdateJob" do
        result

        expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).not_to have_been_enqueued
      end
    end

    context "when plan has fixed charges" do
      let(:add_on) { create(:add_on, organization:) }

      before { create(:fixed_charge, plan:, add_on:) }

      it "emits fixed charge events" do
        expect { result }.to change(FixedChargeEvent, :count).by(1)
      end
    end

    it "enqueues BillSubscriptionJob with only the previous subscription" do
      result

      expect(BillSubscriptionJob).to have_been_enqueued
        .with([previous_subscription], timestamp.to_i, invoicing_reason: :upgrading)
    end

    it "enqueues BillNonInvoiceableFeesJob with only the previous subscription" do
      result

      expect(BillNonInvoiceableFeesJob).to have_been_enqueued
        .with([previous_subscription], timestamp)
    end

    context "when the new plan is pay in advance" do
      let(:plan) { create(:plan, organization:, amount_cents: 50, pay_in_advance: true) }

      it "bills both previous and new subscription" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([previous_subscription, subscription], timestamp.to_i, invoicing_reason: :upgrading)
      end
    end

    context "when the new plan has pay-in-advance fixed charges" do
      let(:add_on) { create(:add_on, organization:) }

      before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

      it "bills both previous and new subscription" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([previous_subscription, subscription], timestamp.to_i, invoicing_reason: :upgrading)
      end
    end

    context "when activation_rules gate the new subscription" do
      let(:plan) { create(:plan, organization:, amount_cents: 50, pay_in_advance: true) }
      let(:subscription) do
        create(
          :subscription,
          :pending,
          :with_activation_rules,
          activation_rules_config: [{type: "payment", timeout_hours: 48}],
          organization:,
          customer:,
          plan:,
          previous_subscription:,
          subscription_at: Time.current
        )
      end

      it "marks the new subscription as incomplete" do
        expect(result.subscription).to be_incomplete
      end

      it "does not terminate the previous subscription" do
        result

        expect(previous_subscription.reload).to be_active
      end

      it "sends a subscription.incomplete webhook" do
        result

        expect(SendWebhookJob).to have_been_enqueued.with("subscription.incomplete", subscription)
      end

      it "enqueues BillSubscriptionJob for the incomplete subscription with skip_charges and :upgrading" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], anything, invoicing_reason: :upgrading, skip_charges: true)
      end
    end

    context "when the subscription is incomplete with no payment rules" do
      let(:plan) { create(:plan, organization:, amount_cents: 50, pay_in_advance: true) }
      let(:subscription) do
        create(
          :subscription,
          :incomplete,
          organization:,
          customer:,
          plan:,
          previous_subscription:,
          subscription_at: Time.current
        )
      end

      it "includes the new subscription in the downgrade bill (never billed during gating)" do
        result

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([previous_subscription, subscription], anything, invoicing_reason: :upgrading)
      end
    end
  end
end
