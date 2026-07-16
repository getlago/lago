# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription do
  subject(:subscription) { create(:subscription, plan:) }

  let(:plan) { create(:plan) }

  it_behaves_like "paper_trail traceable"

  describe "enums" do
    it do
      expect(subject).to define_enum_for(:status).with_values(
        pending: 0,
        active: 1,
        terminated: 2,
        canceled: 3,
        incomplete: 4
      )
      expect(subject).to define_enum_for(:billing_time).with_values(
        calendar: 0,
        anniversary: 1
      )
      expect(subject).to define_enum_for(:on_termination_credit_note)
        .backed_by_column_of_type(:enum)
        .with_values(credit: "credit", skip: "skip", refund: "refund", offset: "offset")
        .with_prefix(:on_termination_credit_note)
      expect(subject).to define_enum_for(:on_termination_invoice)
        .backed_by_column_of_type(:enum)
        .with_values(generate: "generate", skip: "skip")
        .with_prefix(:on_termination_invoice)
      expect(subject).to define_enum_for(:cancellation_reason)
        .backed_by_column_of_type(:enum)
        .with_values(payment_failed: "payment_failed", timeout: "timeout")
    end
  end

  describe "associations" do
    it do
      expect(subject).to belong_to(:customer)
      expect(subject).to belong_to(:plan)
      expect(subject).to belong_to(:previous_subscription).optional
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:billing_entity).optional
      expect(subject).to have_many(:applied_invoice_custom_sections).class_name("Subscription::AppliedInvoiceCustomSection").dependent(:destroy)
      expect(subject).to have_many(:selected_invoice_custom_sections).through(:applied_invoice_custom_sections).source(:invoice_custom_section)
      expect(subject).to have_many(:next_subscriptions).class_name("Subscription").with_foreign_key(:previous_subscription_id)
      expect(subject).to have_many(:events)
      expect(subject).to have_many(:invoice_subscriptions)
      expect(subject).to have_many(:invoices).through(:invoice_subscriptions)
      expect(subject).to have_many(:integration_resources)
      expect(subject).to have_many(:fees)
      expect(subject).to have_many(:daily_usages)
      expect(subject).to have_many(:usage_thresholds)
      expect(subject).to have_many(:fixed_charges).through(:plan)
      expect(subject).to have_many(:fixed_charge_events)
      expect(subject).to have_many(:fixed_charge_units_overrides).class_name("Subscription::FixedChargeUnitsOverride")
      expect(subject).to have_many(:add_ons).through(:fixed_charges)
      expect(subject).to have_one(:lifetime_usage).autosave(true)
      expect(subject).to have_one(:subscription_activity).class_name("UsageMonitoring::SubscriptionActivity")
      expect(subject).to have_many(:entitlements).class_name("Entitlement::Entitlement")
      expect(subject).to have_many(:entitlement_removals).class_name("Entitlement::SubscriptionFeatureRemoval")
      expect(subject).to have_many(:alerts).class_name("UsageMonitoring::Alert")
      expect(subject).to have_many(:activation_rules).class_name("Subscription::ActivationRule")
    end
  end

  describe "Clickhouse associations", clickhouse: true do
    it do
      expect(subject).to have_many(:activity_logs).class_name("Clickhouse::ActivityLog")
    end
  end

  describe "#billing_entity" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }

    context "when subscription has a billing_entity" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:subscription) { create(:subscription, customer:, billing_entity:) }

      it "returns the subscription billing_entity" do
        expect(subscription.billing_entity).to eq(billing_entity)
      end
    end

    context "when subscription does not have a billing_entity" do
      let(:subscription) { create(:subscription, customer:, billing_entity: nil) }

      it "falls back to the customer billing_entity" do
        expect(subscription.billing_entity).to eq(customer.billing_entity)
      end
    end
  end

  describe "#applicable_billing_entity_id" do
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }

    context "when subscription has a billing_entity_id" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:subscription) { create(:subscription, customer:, billing_entity:) }

      it "returns the subscription's own billing_entity_id" do
        expect(subscription.applicable_billing_entity_id).to eq(billing_entity.id)
      end
    end

    context "when subscription has no billing_entity_id" do
      let(:subscription) { create(:subscription, customer:, billing_entity: nil) }

      it "falls back to the customer's billing_entity_id" do
        expect(subscription.applicable_billing_entity_id).to eq(customer.billing_entity_id)
      end
    end
  end

  describe "Scopes" do
    describe ".starting_in_the_future" do
      let(:organization) { create(:organization) }
      let(:customer) { create(:customer, organization:) }
      let!(:pending_subscription_without_previous) { create(:subscription, :pending, customer:) }

      before do
        create(:subscription, :with_previous_subscription, :pending, customer:)
        create(:subscription, :active, customer:)
      end

      it "returns only pending subscriptions without previous subscription" do
        result = described_class.starting_in_the_future

        expect(result).to match_array([pending_subscription_without_previous])
      end
    end

    describe ".expirable" do
      let(:expirable_subscription) do
        create(:subscription, :incomplete).tap do |sub|
          create(:subscription_activation_rule, subscription: sub, status: :pending, expires_at: 1.hour.ago)
        end
      end

      before do
        expirable_subscription

        # incomplete with future expiry — not expirable yet
        sub = create(:subscription, :incomplete)
        create(:subscription_activation_rule, subscription: sub, status: :pending, expires_at: 1.hour.from_now)

        # incomplete with no expiry — not expirable
        sub2 = create(:subscription, :incomplete)
        create(:subscription_activation_rule, subscription: sub2, status: :inactive)

        # active subscription — not expirable
        create(:subscription)
      end

      it "returns only incomplete subscriptions with expirable activation rules" do
        expect(described_class.expirable).to match_array([expirable_subscription])
      end
    end

    describe ".without_fixed_charge_units_override_for" do
      let(:organization) { create(:organization) }
      let(:plan) { create(:plan, organization:) }
      let(:fixed_charge) { create(:fixed_charge, plan:, organization:) }
      let(:other_fixed_charge) { create(:fixed_charge, plan:, organization:) }
      let(:overridden_sub) { create(:subscription, plan:) }
      let(:bare_sub) { create(:subscription, plan:) }
      let(:other_fc_overridden_sub) { create(:subscription, plan:) }

      before do
        create(:subscription_fixed_charge_units_override, subscription: overridden_sub, fixed_charge:, organization:)
        create(:subscription_fixed_charge_units_override, subscription: other_fc_overridden_sub, fixed_charge: other_fixed_charge, organization:)
      end

      it "excludes subscriptions with a kept override for the given fixed charge" do
        result = described_class.without_fixed_charge_units_override_for(fixed_charge)

        expect(result).to include(bare_sub, other_fc_overridden_sub)
        expect(result).not_to include(overridden_sub)
      end

      context "when the override row was discarded" do
        before do
          Subscription::FixedChargeUnitsOverride.unscoped.find_by(subscription: overridden_sub, fixed_charge:).discard!
        end

        it "stops excluding the subscription" do
          expect(described_class.without_fixed_charge_units_override_for(fixed_charge)).to include(overridden_sub)
        end
      end
    end
  end

  describe "validations" do
    it do
      expect(subject).to validate_presence_of(:external_id)
      expect(subject).to validate_presence_of(:billing_time)
    end

    describe "on_termination_credit_note validation" do
      context "when plan is pay in arrears" do
        subject(:subscription) { build(:subscription) }

        it { is_expected.to validate_absence_of(:on_termination_credit_note) }
      end

      context "when plan is pay in advance" do
        subject(:subscription) { build(:subscription, plan: create(:plan, :pay_in_advance)) }

        it { is_expected.to be_valid }
      end
    end

    describe "external_id validation" do
      let(:organization) { create(:organization) }
      let(:customer) { create(:customer, organization:) }
      let(:external_id) { SecureRandom.uuid }
      let(:subscription) do
        create(
          :subscription,
          plan:,
          customer: create(:customer, organization:)
        )
      end

      let(:new_subscription) do
        build(
          :subscription,
          plan:,
          external_id:,
          customer: create(:customer, organization:)
        )
      end

      before { subscription }

      context "when external_id is unique" do
        it "does not raise validation error if external_id is unique" do
          expect(new_subscription).to be_valid
        end
      end

      context "when external_id is NOT unique" do
        let(:external_id) { subscription.external_id }

        it "raises validation error" do
          expect(new_subscription).not_to be_valid
        end
      end

      context "when external_id is taken by an incomplete subscription" do
        let(:external_id) { subscription.external_id }

        before { subscription.incomplete! }

        it "allows an active subscription with the same external_id" do
          expect(new_subscription).to be_valid
        end
      end

      context "when an active and incomplete subscription both exist with the same external_id" do
        let(:external_id) { subscription.external_id }

        before do
          create(
            :subscription,
            plan:,
            status: :incomplete,
            started_at: Time.current,
            external_id:,
            customer: create(:customer, organization:)
          )
        end

        it "rejects a second active subscription" do
          expect(new_subscription).not_to be_valid
        end
      end

      context "when creating an incomplete subscription and one already exists" do
        let(:external_id) { subscription.external_id }

        before { subscription.incomplete! }

        it "rejects a second incomplete subscription" do
          incomplete_sub = build(
            :subscription,
            plan:,
            status: :incomplete,
            started_at: Time.current,
            external_id:,
            customer: create(:customer, organization:)
          )
          expect(incomplete_sub).not_to be_valid
        end
      end

      context "when a pending subscription transitions to active" do
        let(:external_id) { SecureRandom.uuid }
        let(:pending_subscription) do
          create(
            :subscription,
            plan:,
            status: :pending,
            external_id:,
            customer: create(:customer, organization:)
          )
        end

        before { pending_subscription }

        context "when another active subscription with the same external_id exists" do
          before do
            create(
              :subscription,
              plan:,
              status: :active,
              external_id:,
              customer: create(:customer, organization:)
            )
          end

          it "rejects the activation" do
            pending_subscription.assign_attributes(status: :active)
            expect(pending_subscription).not_to be_valid
            expect(pending_subscription.errors[:external_id]).to include("value_already_exist")
          end
        end

        context "when no other active subscription with the same external_id exists" do
          it "allows the activation" do
            pending_subscription.assign_attributes(status: :active)
            expect(pending_subscription).to be_valid
          end
        end
      end
    end

    describe "started_at validation" do
      context "when status is active" do
        it "is valid without started_at" do
          sub = build(:subscription, started_at: nil)
          expect(sub).to be_valid
        end
      end

      context "when status is incomplete" do
        it "is invalid without started_at" do
          sub = build(:subscription, :incomplete, started_at: nil)
          expect(sub).not_to be_valid
          expect(sub.errors[:started_at]).to be_present
        end
      end

      context "when status is pending" do
        it "is valid without started_at" do
          sub = build(:subscription, :pending)
          expect(sub).to be_valid
        end
      end
    end
  end

  describe "#mark_as_incomplete!" do
    let(:subscription) { create(:subscription, :pending) }

    it "sets started_at and changes status to incomplete" do
      freeze_time do
        subscription.mark_as_incomplete!

        expect(subscription.status).to eq("incomplete")
        expect(subscription.started_at).to eq(Time.current)
        expect(subscription.activated_at).to be_nil
      end
    end
  end

  describe "#pending_rules?" do
    subject(:pending_rules?) { subscription.pending_rules? }

    let(:subscription) { create(:subscription) }

    context "when there are pending activation rules" do
      before { create(:subscription_activation_rule, subscription:, status: :pending) }

      it { is_expected.to be(true) }
    end

    context "when there are no pending activation rules" do
      before do
        create(:subscription_activation_rule, subscription:, status: :inactive)
      end

      it { is_expected.to be(false) }
    end

    context "when activation rules are satisfied" do
      before do
        create(:subscription_activation_rule, subscription:, status: :satisfied)
      end

      it { is_expected.to be(false) }
    end
  end

  describe "#gated?" do
    subject(:gated?) { subscription.gated? }

    context "when incomplete with pending rules" do
      let(:subscription) { create(:subscription, :incomplete) }

      before { create(:subscription_activation_rule, subscription:, status: :pending) }

      it { is_expected.to be(true) }
    end

    context "when active with pending rules" do
      let(:subscription) { create(:subscription) }

      before { create(:subscription_activation_rule, subscription:, status: :pending) }

      it { is_expected.to be(false) }
    end

    context "when incomplete without satisfied rules" do
      let(:subscription) { create(:subscription, :incomplete) }

      before { create(:subscription_activation_rule, subscription:, status: :satisfied) }

      it { is_expected.to be(false) }
    end
  end

  describe "#payment_gated?" do
    subject(:payment_gated?) { subscription.payment_gated? }

    context "when incomplete with pending payment rule" do
      let(:subscription) do
        create(:subscription, :incomplete, :with_activation_rules,
          activation_rules_config: [{type: "payment", timeout_hours: 48, status: "pending"}])
      end

      it { is_expected.to be(true) }
    end

    context "when incomplete with satisfied payment rule" do
      let(:subscription) do
        create(:subscription, :incomplete, :with_activation_rules,
          activation_rules_config: [{type: "payment", timeout_hours: 48, status: "satisfied"}])
      end

      it { is_expected.to be(false) }
    end

    context "when active with pending payment rule" do
      let(:subscription) do
        create(:subscription, :with_activation_rules,
          activation_rules_config: [{type: "payment", timeout_hours: 48, status: "pending"}])
      end

      it { is_expected.to be(false) }
    end

    context "when pending with pending payment rule" do
      let(:subscription) do
        create(:subscription, :pending, :with_activation_rules,
          activation_rules_config: [{type: "payment", timeout_hours: 48, status: "pending"}])
      end

      it { is_expected.to be(false) }
    end

    context "when incomplete with no activation rules" do
      let(:subscription) { create(:subscription, :incomplete) }

      it { is_expected.to be(false) }
    end
  end

  describe "#upgraded?" do
    let(:previous_subscription) { nil }
    let(:subscription) do
      create(:subscription, previous_subscription:, plan:)
    end

    context "without next subscription" do
      it { expect(subscription).not_to be_upgraded }
    end

    context "with next subscription" do
      let(:previous_plan) { create(:plan) }
      let(:previous_subscription) do
        create(:subscription, plan: previous_plan)
      end

      before { subscription }

      it { expect(previous_subscription).to be_upgraded }

      context "when previous plan was more expensive" do
        let(:previous_plan) do
          create(:plan, amount_cents: plan.amount_cents + 10)
        end

        it { expect(previous_subscription).not_to be_upgraded }
      end

      context "when plans have different intervals" do
        before do
          previous_plan.update!(interval: "monthly")
          plan.update!(interval: "yearly")
        end

        it { expect(previous_subscription).not_to be_upgraded }
      end
    end
  end

  describe "#downgraded?" do
    let(:previous_subscription) { nil }
    let(:plan) { create(:plan, amount_cents: 100) }

    let(:subscription) do
      create(:subscription, previous_subscription:, plan:)
    end

    context "without next subscription" do
      it { expect(subscription).not_to be_downgraded }
    end

    context "with next subscription" do
      let(:previous_plan) { create(:plan, amount_cents: 200) }
      let(:previous_subscription) do
        create(:subscription, plan: previous_plan)
      end

      before { subscription }

      it { expect(previous_subscription).to be_downgraded }

      context "when previous plan was less expensive" do
        let(:previous_plan) do
          create(:plan, amount_cents: plan.amount_cents - 10)
        end

        it { expect(previous_subscription).not_to be_downgraded }
      end

      context "when plans have different intervals" do
        before do
          previous_plan.update!(interval: "yearly")
          plan.update!(interval: "monthly")
        end

        it { expect(previous_subscription).not_to be_downgraded }
      end
    end
  end

  describe "#trial_end_date" do
    let(:plan) { create(:plan, trial_period: 3) }

    it "returns the trial end date" do
      trial_end_date = subscription.trial_end_date

      expect(trial_end_date).to be_present
      expect(trial_end_date).to eq(subscription.started_at.to_date + 3.days)
    end

    context "when plan has no trial" do
      let(:plan) { create(:plan) }

      it "returns nil" do
        expect(subscription.trial_end_date).to be_nil
      end
    end

    context "with a previous subscription" do
      let(:subscription) do
        create(
          :subscription,
          previous_subscription:,
          started_at: Time.zone.yesterday,
          plan:,
          external_id: "sub_id",
          customer: previous_subscription.customer
        )
      end
      let(:previous_subscription) do
        create(:subscription, started_at: Time.current.last_month, external_id: "sub_id", status: :terminated)
      end

      it "takes previous subscription started_at into account" do
        trial_end_date = subscription.trial_end_date

        expect(trial_end_date).to be_present
        expect(trial_end_date).to eq(previous_subscription.started_at.to_date + 3.days)
      end
    end
  end

  describe "#trial_end_datetime" do
    let(:plan) { create(:plan, trial_period: 3) }
    let(:started_at) { subscription.initial_started_at }

    it "returns the trial end datetime" do
      trial_end_datetime = subscription.trial_end_datetime

      expect(trial_end_datetime).to be_present
      expect(trial_end_datetime).to eq(started_at + 3.days)
    end

    context "when plan has no trial" do
      let(:plan) { create(:plan) }

      it "returns nil" do
        expect(subscription.trial_end_datetime).to be_nil
      end
    end

    context "with a previous subscription" do
      let(:subscription) do
        create(
          :subscription,
          previous_subscription:,
          started_at: Time.zone.yesterday,
          plan:,
          external_id: "sub_id",
          customer: previous_subscription.customer
        )
      end
      let(:previous_subscription) do
        create(:subscription, started_at: Time.current.last_month, external_id: "sub_id", status: :terminated)
      end

      it "takes previous subscription started_at into account" do
        trial_end_datetime = subscription.trial_end_datetime

        expect(trial_end_datetime).to be_present
        expect(trial_end_datetime).to eq(started_at + 3.days)
      end
    end
  end

  describe "#in_trial_period?" do
    context "when plan has no trial" do
      it { expect(subscription.in_trial_period?).to be false }
    end

    context "when subscription is in trial" do
      let(:subscription) { create(:subscription, plan:, started_at: 5.days.ago) }
      let(:plan) { create(:plan, trial_period: 10) }

      it { expect(subscription.in_trial_period?).to be true }
    end

    context "when subscription trial has ended" do
      let(:subscription) { create(:subscription, plan:, started_at: 5.days.ago) }
      let(:plan) { create(:plan, trial_period: 2) }

      it { expect(subscription.in_trial_period?).to be false }
    end
  end

  describe "#billing_reference_time" do
    around { |example| travel_to(Time.zone.parse("2026-06-04T10:00:00Z")) { example.run } }

    context "when the subscription has already started" do
      let(:subscription) { build(:subscription, started_at: Time.zone.parse("2026-03-03T00:00:00Z")) }

      it "returns the current time" do
        expect(subscription.billing_reference_time).to eq(Time.current)
      end
    end

    context "when the subscription starts in the future" do
      let(:subscription) { build(:subscription, started_at: Time.zone.parse("2026-07-03T00:00:00Z")) }

      it "returns started_at" do
        expect(subscription.billing_reference_time).to eq(subscription.started_at)
      end
    end

    context "when started_at is nil" do
      let(:subscription) { build(:subscription, started_at: nil) }

      it "falls back to the current time" do
        expect(subscription.billing_reference_time).to eq(Time.current)
      end
    end
  end

  describe "#initial_started_at" do
    let(:customer) { create(:customer) }
    let(:subscription) do
      create(
        :subscription,
        previous_subscription:,
        started_at: Time.zone.yesterday,
        external_id: "sub_id",
        customer:
      )
    end

    let(:previous_subscription) { nil }

    it "returns the subscription started_at" do
      expect(subscription.initial_started_at).to eq(subscription.started_at)
    end

    context "with a previous subscription" do
      let(:previous_subscription) do
        create(
          :subscription,
          started_at: Time.current.last_month,
          status: :terminated,
          external_id: "sub_id",
          customer:
        )
      end

      it "returns the previous subscription started_at" do
        expect(subscription.initial_started_at.to_date).to eq(previous_subscription.started_at.to_date)
      end
    end

    context "with two previous subscriptions" do
      let(:previous_subscription) do
        create(
          :subscription,
          previous_subscription: initial_subscription,
          started_at: Time.zone.yesterday,
          external_id: "sub_id",
          customer:,
          status: :terminated
        )
      end

      let(:initial_subscription) do
        create(
          :subscription,
          started_at: Time.current.last_year,
          external_id: "sub_id",
          status: :terminated,
          customer:
        )
      end

      it "returns the initial subscription started_at" do
        expect(subscription.initial_started_at.to_date).to eq(initial_subscription.started_at.to_date)
      end
    end
  end

  describe "#downgrade_plan_date" do
    let(:subscription) { create(:subscription) }

    context "without next subscription" do
      it "returns nil" do
        expect(subscription.downgrade_plan_date).to be_nil
      end
    end

    context "without pending next subscription" do
      it "returns nil" do
        create(:subscription, previous_subscription: subscription, status: :active)
        expect(subscription.downgrade_plan_date).to be_nil
      end
    end

    context "with active downgraded next subscription" do
      let(:plan) { create(:plan, amount_cents: 200) }
      let(:next_plan) { create(:plan, amount_cents: 100) }
      let(:subscription) { create(:subscription, :terminated, plan:) }

      it "returns the date when the plan was downgraded" do
        create(
          :subscription,
          previous_subscription: subscription,
          plan: next_plan,
          status: :active,
          started_at: Time.zone.parse("2022-07-01T00:00:00Z")
        )

        expect(subscription.downgrade_plan_date).to eq(Date.parse("1 Jul 2022"))
      end
    end

    context "with anniversary billing before the downgrade date" do
      let(:started_at) { Time.zone.parse("2022-06-04T00:00:00Z") }
      let(:subscription) do
        create(
          :subscription,
          :anniversary,
          started_at:,
          subscription_at: started_at
        )
      end

      it "returns the next anniversary date" do
        create(:subscription, previous_subscription: subscription, status: :pending)

        travel_to(Time.zone.parse("2022-07-03T00:00:00Z")) do
          expect(subscription.downgrade_plan_date).to eq(Date.parse("4 Jul 2022"))
        end
      end
    end

    it "returns the date when the plan will be downgraded" do
      current_date = DateTime.parse("20 Jun 2022")
      create(:subscription, previous_subscription: subscription, status: :pending)

      travel_to(current_date) do
        expect(subscription.downgrade_plan_date).to eq(Date.parse("1 Jul 2022"))
      end
    end
  end

  describe "#starting_in_the_future?" do
    context "when subscription is active" do
      let(:subscription) { create(:subscription) }

      it "returns false" do
        expect(subscription.starting_in_the_future?).to be false
      end
    end

    context "when subscription is pending and starting in the future" do
      let(:subscription) { create(:subscription, :pending) }

      it "returns true" do
        expect(subscription.starting_in_the_future?).to be true
      end
    end

    context "when subscription is pending and downgraded" do
      let(:old_subscription) { create(:subscription) }
      let(:subscription) { create(:subscription, :pending, previous_subscription: old_subscription) }

      it "returns false" do
        expect(subscription.starting_in_the_future?).to be false
      end
    end
  end

  describe "#display_name" do
    let(:subscription) { build(:subscription, name: subscription_name, plan:) }
    let(:subscription_name) { "some_name" }
    let(:plan) { create(:plan, name: "some_plan_name") }

    it { expect(subscription.display_name).to eq("some_name") }

    context "when name is empty" do
      let(:subscription_name) { nil }

      it "returns the plan name" do
        expect(subscription.display_name).to eq("some_plan_name")
      end
    end
  end

  describe "#invoice_name" do
    subject(:subscription_invoice_name) { subscription.invoice_name }

    let(:subscription) { build(:subscription, plan:, name:, organization: plan.organization) }

    context "when plan invoice display name is blank" do
      let(:plan) { build_stubbed(:plan, invoice_display_name: [nil, ""].sample) }

      context "when subscription name is blank" do
        let(:name) { [nil, ""].sample }

        it "returns plan name" do
          expect(subscription_invoice_name).to eq(plan.name)
        end
      end

      context "when subscription name is present" do
        let(:name) { Faker::TvShows::GameOfThrones.characters }

        it "returns subscription name" do
          expect(subscription_invoice_name).to eq(subscription.name)
        end
      end
    end

    context "when plan invoice display name is present" do
      let(:plan) { build_stubbed(:plan) }

      context "when subscription name is blank" do
        let(:name) { [nil, ""].sample }

        it "returns plan invoice display name" do
          expect(subscription_invoice_name).to eq(plan.invoice_display_name)
        end
      end

      context "when subscription name is present" do
        let(:name) { Faker::TvShows::GameOfThrones.characters }

        it "returns subscription name" do
          expect(subscription_invoice_name).to eq(subscription.name)
        end
      end
    end
  end

  describe "#should_sync_hubspot_subscription??" do
    subject(:method_call) { subscription.should_sync_hubspot_subscription? }

    let(:subscription) { create(:subscription, customer:) }
    let(:organization) { create(:organization) }
    let(:customer) { create(:customer, organization:) }

    context "without integration hubspot customer" do
      it "returns false" do
        expect(method_call).to eq(false)
      end
    end

    context "with integration hubspot customer" do
      let(:integration_customer) { create(:hubspot_customer, integration:, customer:) }
      let(:integration) { create(:hubspot_integration, organization:, sync_subscriptions:) }

      before { integration_customer }

      context "when sync subscriptions is true" do
        let(:sync_subscriptions) { true }

        it "returns true" do
          expect(method_call).to eq(true)
        end
      end

      context "when sync subscriptions is false" do
        let(:sync_subscriptions) { false }

        it "returns false" do
          expect(method_call).to eq(false)
        end
      end
    end
  end

  describe ".date_diff_with_timezone" do
    let(:from_datetime) { Time.zone.parse("2023-08-31T23:10:00") }
    let(:to_datetime) { Time.zone.parse("2023-09-30T22:59:59") }
    let(:customer) { create(:customer, timezone:) }
    let(:terminated_at) { nil }
    let(:timezone) { "Europe/Paris" }

    let(:subscription) do
      create(
        :subscription,
        plan:,
        customer:,
        terminated_at:
      )
    end

    let(:result) do
      subscription.date_diff_with_timezone(from_datetime, to_datetime)
    end

    it "returns the number of days between the two datetime" do
      expect(result).to eq(30)
    end

    context "with terminated and upgraded subscription" do
      let(:terminated_at) { Time.zone.parse("2023-09-30T22:59:59") }
      let(:new_subscription) do
        create(
          :subscription,
          plan:,
          customer:,
          previous_subscription_id: subscription.id
        )
      end

      before do
        subscription.terminated!
        new_subscription
      end

      it "takes the daylight saving time into account" do
        expect(result).to eq(29)
      end
    end
  end

  describe "#mark_as_active!" do
    subject(:subscription) { create(:subscription, :pending) }

    it "changes the status to active and sets started_at and activated_at" do
      freeze_time do
        expect { subscription.mark_as_active! }
          .to change(subscription, :status).from("pending").to("active")

        expect(subscription.started_at).to eq(Time.current)
        expect(subscription.activated_at).to eq(Time.current)
        expect(subscription.lifetime_usage).to be_present
      end
    end

    context "when subscription was incomplete (already has started_at)" do
      subject(:subscription) { create(:subscription, :incomplete) }

      it "preserves started_at and sets activated_at" do
        original_started_at = subscription.started_at

        freeze_time do
          expect { subscription.mark_as_active! }
            .to change(subscription, :status).from("incomplete").to("active")

          expect(subscription.started_at).to eq(original_started_at)
          expect(subscription.activated_at).to eq(Time.current)
        end
      end
    end

    context "with a previous subscription" do
      subject(:subscription) { create(:subscription, :pending, previous_subscription:) }

      let(:previous_subscription) { create(:subscription, :terminated) }
      let(:lifetime_usage) { create(:lifetime_usage, subscription: previous_subscription) }

      before { lifetime_usage }

      it "changes the status to active" do
        expect { subscription.mark_as_active! }
          .to change(subscription, :status).from("pending").to("active")

        expect(lifetime_usage.reload.subscription).to eq(subscription)
      end
    end
  end

  describe "#terminated_at?" do
    context "when subscription is terminated before the timestamp" do
      it "returns true" do
        subscription = build(:subscription, :terminated, terminated_at: 2.days.ago)
        expect(subscription.terminated_at?(1.day.ago)).to be true
      end
    end

    context "when subscription is terminated after the timestamp" do
      it "returns false" do
        subscription = build(:subscription, :terminated, terminated_at: 1.day.from_now)
        expect(subscription.terminated_at?(2.days.ago)).to be false
      end
    end

    context "when subscription is not terminated" do
      it "returns false" do
        subscription = build(:subscription)
        expect(subscription.terminated_at?(1.day.ago)).to be false
      end
    end
  end

  describe "#adjusted_boundaries" do
    let(:timestamp) { Time.zone.parse("30 Mar 2024") }
    let(:billing_date) { Time.zone.parse("15 May 2024") }
    let(:date_service) { Subscriptions::DatesService.new_instance(subscription, billing_date) }
    let(:plan) { create(:plan, amount_cents: 100) }
    let(:status) { "active" }
    let(:terminated_at) { nil }
    let(:subscription) do
      create(
        :subscription,
        billing_time: "calendar",
        started_at: timestamp,
        created_at: timestamp,
        status:,
        terminated_at:,
        subscription_at: timestamp,
        plan:
      )
    end
    let(:default_boundaries) do
      {
        from_datetime: date_service.from_datetime,
        to_datetime: date_service.to_datetime,
        charges_from_datetime: date_service.charges_from_datetime,
        charges_to_datetime: date_service.charges_to_datetime,
        fixed_charges_from_datetime: date_service.fixed_charges_from_datetime,
        fixed_charges_to_datetime: date_service.fixed_charges_to_datetime,
        timestamp: billing_date
      }
    end

    context "with active subscription" do
      let(:billing_date) { Time.zone.parse("01 Jun 2024") }

      it "returns default boundaries" do
        expect(subscription.adjusted_boundaries(billing_date, default_boundaries)).to eq(default_boundaries)
      end
    end

    context "with termination on non billing day" do
      let(:status) { "terminated" }
      let(:terminated_at) { billing_date }

      it "returns default boundaries" do
        expect(subscription.adjusted_boundaries(billing_date, default_boundaries)).to eq(default_boundaries)
      end
    end

    context "with termination on billing day without invoice for previous period" do
      let(:status) { "terminated" }
      let(:billing_date) { Time.zone.parse("01 Jun 2024") }
      let(:terminated_at) { billing_date }

      it "returns new boundaries based on previous billing period" do
        new_boundaries = subscription.adjusted_boundaries(billing_date, default_boundaries)

        expect(new_boundaries).not_to eq(default_boundaries)
        expect(new_boundaries.from_datetime.iso8601).to eq("2024-05-01T00:00:00Z")
        expect(new_boundaries.to_datetime.iso8601).to eq("2024-05-31T23:59:59Z")
        expect(new_boundaries.charges_from_datetime.iso8601).to eq("2024-05-01T00:00:00Z")
        expect(new_boundaries.charges_to_datetime.iso8601).to eq("2024-05-31T23:59:59Z")
        expect(new_boundaries.fixed_charges_from_datetime.iso8601).to eq("2024-05-01T00:00:00Z")
        expect(new_boundaries.fixed_charges_to_datetime.iso8601).to eq("2024-05-31T23:59:59Z")
      end
    end
  end

  describe "#next_subscription" do
    subject { subscription.next_subscription }

    let(:subscription) { build(:subscription, next_subscriptions:, organization: plan.organization) }

    let(:next_subscriptions) do
      [
        build(:subscription, :canceled, organization: plan.organization),
        build(:subscription, created_at: 1.day.ago, organization: plan.organization),
        build(:subscription, created_at: 2.days.ago, organization: plan.organization)
      ]
    end

    it "returns most recently non-canceled next subscription" do
      expect(subject).to eq next_subscriptions.second
    end
  end

  describe "#has_progressive_billing?" do
    let(:plan) { create(:plan) }

    context "when plan has usage thresholds" do
      before { create(:usage_threshold, plan:) }

      it "returns true" do
        expect(subscription.has_progressive_billing?).to be(true)
      end
    end

    context "when plan has no usage thresholds" do
      it "returns false" do
        expect(subscription.has_progressive_billing?).to be(false)
      end
    end
  end

  describe "#applicable_usage_thresholds" do
    let(:plan_threshold) { create(:usage_threshold, plan:) }

    context "when subscription has its own usage thresholds" do
      let(:subscription_threshold) { create(:usage_threshold, :for_subscription, subscription:) }

      before do
        plan_threshold
        subscription_threshold
      end

      it "returns subscription usage thresholds" do
        expect(subscription.applicable_usage_thresholds).to contain_exactly(subscription_threshold)
      end

      context "when progressive billing is disabled for subscription" do
        it "returns empty array" do
          subscription.progressive_billing_disabled = true
          expect(subscription.applicable_usage_thresholds).to be_empty
        end
      end
    end

    context "when subscription has no usage thresholds" do
      it "returns plan usage thresholds" do
        plan_threshold
        expect(subscription.applicable_usage_thresholds).to contain_exactly(plan_threshold)
      end

      context "when progressive billing is disabled for subscription" do
        it "returns empty array" do
          subscription.progressive_billing_disabled = true
          expect(subscription.applicable_usage_thresholds).to be_empty
        end
      end

      context "when plan is a child with no thresholds" do
        let(:parent_plan) { create(:plan) }
        let(:plan) { create(:plan, parent: parent_plan) }
        let(:plan_threshold) { create(:usage_threshold, plan: parent_plan) }

        it "returns the parent plan usage thresholds" do
          plan_threshold
          expect(subscription.applicable_usage_thresholds).to contain_exactly(plan_threshold)
        end
      end
    end

    context "when neither subscription nor plan has usage thresholds" do
      it "returns empty collection" do
        expect(subscription.applicable_usage_thresholds).to be_empty
      end
    end
  end
end
