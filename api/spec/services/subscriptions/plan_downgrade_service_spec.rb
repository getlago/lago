# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::PlanDowngradeService do
  subject(:result) do
    described_class.call(customer:, current_subscription: subscription, plan:, params:)
  end

  let(:subscription) do
    create(
      :subscription,
      customer:,
      plan: old_plan,
      subscription_at: Time.current,
      external_id: SecureRandom.uuid
    )
  end

  let(:old_plan) { create(:plan, amount_cents: 100, organization:, amount_currency: currency) }
  let(:customer) { create(:customer, :with_hubspot_integration, organization:, currency:) }
  let(:organization) { create(:organization) }
  let(:currency) { "EUR" }
  let(:plan) { create(:plan, amount_cents: 50, organization:) }
  let(:params) { {name: subscription_name} }
  let(:subscription_name) { "new invoice display name" }

  describe "#call" do
    it "creates a new pending next subscription" do
      expect(result).to be_success

      next_subscription = result.subscription.next_subscription
      expect(next_subscription.id).not_to eq(subscription.id)
      expect(next_subscription).to be_pending
      expect(next_subscription.name).to eq(subscription_name)
      expect(next_subscription.plan_id).to eq(plan.id)
      expect(next_subscription.subscription_at).to eq(subscription.subscription_at)
      expect(next_subscription.previous_subscription).to eq(subscription)
      expect(next_subscription.ending_at).to eq(subscription.ending_at)
      expect(next_subscription.lifetime_usage).to be_nil
      expect(next_subscription.payment_method_id).to be_nil
      expect(next_subscription.payment_method_type).to eq("provider")
    end

    it "sends subscription.updated webhook on the current subscription" do
      result
      expect(SendWebhookJob).to have_been_enqueued.with("subscription.updated", subscription)
    end

    it "produces a subscription.updated activity log on the current subscription" do
      result
      expect(Utils::ActivityLog).to have_produced("subscription.updated").with(subscription)
    end

    it "keeps the current subscription active" do
      expect(result.subscription.id).to eq(subscription.id)
      expect(result.subscription).to be_active
      expect(result.subscription.next_subscription).to be_present
    end

    context "with payment method" do
      let(:payment_method) { create(:payment_method, organization:, customer:) }
      let(:params) do
        {
          name: subscription_name,
          payment_method: {
            payment_method_id: payment_method.id,
            payment_method_type: "provider"
          }
        }
      end

      before { payment_method }

      it "propagates the payment method to the new subscription" do
        next_subscription = result.subscription.next_subscription
        expect(next_subscription.payment_method_id).to eq(payment_method.id)
        expect(next_subscription.payment_method_type).to eq("provider")
      end
    end

    context "with invoice custom sections" do
      let(:section) { create(:invoice_custom_section, organization:, code: "section_code_1") }
      let(:params) do
        {
          name: subscription_name,
          invoice_custom_section: {invoice_custom_section_codes: [section.code]}
        }
      end

      before do
        section
        CurrentContext.source = "api"
      end

      it "attaches the section to the new subscription" do
        expect(result).to be_success

        next_subscription = result.subscription.next_subscription.reload
        expect(next_subscription.applied_invoice_custom_sections.count).to be(1)
        expect(next_subscription.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section.id)
      end
    end

    context "when plan has fixed charges" do
      let(:fixed_charge_1) { create(:fixed_charge, plan:) }
      let(:fixed_charge_2) { create(:fixed_charge, plan:) }

      before do
        fixed_charge_1
        fixed_charge_2
      end

      it "does not create fixed charge events on the new subscription" do
        expect(result).to be_success

        next_subscription = result.subscription.next_subscription
        expect(next_subscription).to be_pending
        expect(next_subscription.fixed_charge_events.count).to eq(0)
      end
    end

    context "when ending_at is overridden" do
      let(:overridden_ending_at) { Time.current.beginning_of_day + 3.months }
      let(:params) { {name: subscription_name, ending_at: overridden_ending_at} }

      it "applies the overridden ending_at to the new subscription" do
        expect(result).to be_success

        next_subscription = result.subscription.next_subscription
        expect(next_subscription.ending_at).to eq(overridden_ending_at)
      end
    end

    context "with plan overrides", :premium do
      let(:params) do
        {
          name: subscription_name,
          plan_overrides: {amount_cents: 25}
        }
      end

      it "creates the new subscription with the overridden plan" do
        expect(result).to be_success

        next_subscription = result.subscription.next_subscription
        expect(next_subscription.plan.amount_cents).to eq(25)
        expect(next_subscription.plan.parent_id).to eq(plan.id)
      end
    end

    context "with activation_rules in params" do
      let(:params) do
        {
          name: subscription_name,
          activation_rules: [{type: "payment", timeout_hours: 48}]
        }
      end

      it "applies the activation rules to the new pending next subscription" do
        expect(result).to be_success

        next_subscription = result.subscription.next_subscription
        rules = next_subscription.activation_rules
        expect(rules.count).to eq(1)
        expect(rules.first).to be_inactive
        expect(rules.first.timeout_hours).to eq(48)
      end
    end

    context "when current subscription is pending" do
      let(:subscription) do
        create(
          :subscription,
          :pending,
          customer:,
          plan: old_plan,
          subscription_at: Time.current,
          external_id: SecureRandom.uuid
        )
      end

      it "returns the existing subscription with updated attributes" do
        expect(result).to be_success
        expect(result.subscription.id).to eq(subscription.id)
        expect(result.subscription.plan_id).to eq(plan.id)
        expect(result.subscription.name).to eq(subscription_name)
      end

      context "without a name in params" do
        let(:params) { {} }

        it "does not change the existing subscription name" do
          original_name = subscription.name
          expect(result).to be_success
          expect(result.subscription.name).to eq(original_name)
        end
      end

      context "without Hubspot integration on the customer" do
        let(:customer) { create(:customer, organization:, currency:) }

        it "does not enqueue the Hubspot update job" do
          result
          expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).not_to have_been_enqueued
        end
      end

      context "with activation_rules in params" do
        let(:params) do
          {
            name: subscription_name,
            activation_rules: [{type: "payment", timeout_hours: 48}]
          }
        end

        it "applies the activation rules to the current pending subscription" do
          expect(result).to be_success

          rules = subscription.reload.activation_rules
          expect(rules.count).to eq(1)
          expect(rules.first).to be_inactive
          expect(rules.first.timeout_hours).to eq(48)
        end

        it "updates the pending subscription's plan and name" do
          expect(result).to be_success
          expect(result.subscription.id).to eq(subscription.id)
          expect(result.subscription.plan_id).to eq(plan.id)
          expect(result.subscription.name).to eq(subscription_name)
        end
      end

      context "with an empty activation_rules array in params" do
        let(:existing_rule) { create(:subscription_activation_rule, subscription:, organization:) }
        let(:params) do
          {
            name: subscription_name,
            activation_rules: []
          }
        end

        before { existing_rule }

        it "removes the activation rules from the current subscription" do
          expect { result }
            .to change { subscription.reload.activation_rules.count }
            .from(1).to(0)
        end
      end
    end

    context "with pending next subscription" do
      let(:existing_next_subscription) do
        create(
          :subscription,
          status: :pending,
          previous_subscription: subscription,
          organization:,
          customer:
        )
      end

      before { existing_next_subscription }

      it "cancels the existing pending next subscription" do
        expect(result).to be_success
        expect(existing_next_subscription.reload).to be_canceled
      end
    end

    context "when the new subscription fails validation" do
      before do
        allow(subscription.next_subscriptions).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid.new(Subscription.new))
      end

      it "returns a validation failure" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
      end
    end
  end
end
