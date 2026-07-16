# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:billing_entity_id).of_type("ID")
    expect(subject).to have_field(:customer).of_type("Customer!")
    expect(subject).to have_field(:external_id).of_type("String!")
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:plan).of_type("Plan!")

    expect(subject).to have_field(:name).of_type("String")
    expect(subject).to have_field(:next_name).of_type("String")
    expect(subject).to have_field(:period_end_date).of_type("ISO8601Date")
    expect(subject).to have_field(:status).of_type("StatusTypeEnum")

    expect(subject).to have_field(:billing_time).of_type("BillingTimeEnum")
    expect(subject).to have_field(:canceled_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:ending_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:started_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:subscription_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:terminated_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:on_termination_credit_note).of_type("OnTerminationCreditNoteEnum")
    expect(subject).to have_field(:on_termination_invoice).of_type("OnTerminationInvoiceEnum!")

    expect(subject).to have_field(:selected_invoice_custom_sections).of_type("[InvoiceCustomSection!]")
    expect(subject).to have_field(:skip_invoice_custom_sections).of_type("Boolean")

    expect(subject).to have_field(:current_billing_period_started_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:current_billing_period_ending_at).of_type("ISO8601DateTime")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")

    expect(subject).to have_field(:next_plan).of_type("Plan")
    expect(subject).to have_field(:next_subscription).of_type("Subscription")
    expect(subject).to have_field(:next_subscription_type).of_type("NextSubscriptionTypeEnum")
    expect(subject).to have_field(:next_subscription_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:downgrade_plan_date).of_type("ISO8601Date")
    expect(subject).to have_field(:previous_plan).of_type("Plan")
    expect(subject).to have_field(:previous_subscription).of_type("Subscription")

    expect(subject).to have_field(:activity_logs).of_type("[ActivityLog!]")
    expect(subject).to have_field(:charges).of_type("[Charge!]")
    expect(subject).to have_field(:fees).of_type("[Fee!]")
    expect(subject).to have_field(:fixed_charges).of_type("[FixedCharge!]")

    expect(subject).to have_field(:lifetime_usage).of_type("SubscriptionLifetimeUsage")

    expect(subject).to have_field(:usage_thresholds).of_type("[UsageThreshold!]!")

    expect(subject).to have_field(:payment_method).of_type("PaymentMethod")
    expect(subject).to have_field(:payment_method_type).of_type("PaymentMethodTypeEnum")
    expect(subject).to have_field(:consolidate_invoice).of_type("Boolean!")

    expect(subject).to have_field(:activated_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:activation_rules).of_type("[SubscriptionActivationRule!]!")
    expect(subject).to have_field(:cancellation_reason).of_type("CancellationReasonEnum")
  end

  context "when the subscription starts in the future" do
    let(:plan) { create(:plan, interval: "monthly", pay_in_advance: true) }
    let(:future_start) { Time.zone.parse("2026-07-03T00:00:00Z") }
    let(:subscription) do
      create(
        :subscription,
        :anniversary,
        plan:,
        status: :active,
        subscription_at: future_start,
        started_at: future_start,
        activated_at: future_start,
        created_at: future_start
      )
    end

    around { |example| travel_to(Time.zone.parse("2026-06-04T10:00:00Z")) { example.run } }

    describe "#current_billing_period_started_at" do
      subject { run_graphql_field("Subscription.currentBillingPeriodStartedAt", subscription) }

      it "returns the start of the first real billing period" do
        expect(subject.iso8601).to eq("2026-07-03T00:00:00Z")
      end
    end

    describe "#current_billing_period_ending_at" do
      subject { run_graphql_field("Subscription.currentBillingPeriodEndingAt", subscription) }

      it "returns the end of the first real billing period instead of collapsing onto started_at" do
        expect(subject.iso8601).to eq("2026-08-02T23:59:59Z")
      end
    end

    describe "#period_end_date" do
      subject { run_graphql_field("Subscription.periodEndDate", subscription) }

      it "returns the first period end, not a period that precedes the subscription start" do
        expect(subject.to_date).to eq(Date.parse("2026-08-02"))
      end
    end
  end
end
