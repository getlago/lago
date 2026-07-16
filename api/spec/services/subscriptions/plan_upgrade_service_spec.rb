# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::PlanUpgradeService do
  subject(:result) do
    described_class.call(current_subscription: subscription, plan:, params:)
  end

  let(:subscription) do
    create(
      :subscription,
      customer:,
      plan: old_plan,
      status: :active,
      subscription_at: Time.current,
      started_at: Time.current,
      external_id: SecureRandom.uuid
    )
  end

  let(:old_plan) { create(:plan, amount_cents: 100, organization:, amount_currency: currency) }
  let(:customer) { create(:customer, :with_hubspot_integration, organization:, currency:) }
  let(:organization) { create(:organization) }
  let(:currency) { "EUR" }
  let(:plan) { create(:plan, amount_cents: 100, organization:) }
  let(:params) { {name: subscription_name} }
  let(:subscription_name) { "new invoice display name" }

  describe "#call" do
    before do
      subscription.mark_as_active!
    end

    it "terminates the existing subscription" do
      expect { result }
        .to change { subscription.reload.status }.from("active").to("terminated")
    end

    it "moves the lifetime_usage to the new subscription" do
      lifetime_usage = subscription.lifetime_usage
      expect(result.subscription.lifetime_usage).to eq(lifetime_usage.reload)
      expect(subscription.reload.lifetime_usage).to be_nil
    end

    it "sends terminated and started subscription webhooks" do
      result
      expect(SendWebhookJob).to have_been_enqueued.with("subscription.terminated", subscription)
      expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", result.subscription)
    end

    it "produces an activity log" do
      result
      expect(Utils::ActivityLog).to have_produced("subscription.started").with(result.subscription)
    end

    it "enqueues the Hubspot update job" do
      # TODO: review this one, this one should fail because the code conditional
      # is not meet by the test setup...
      # The subscription does not start in the future
      result
      expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).to have_been_enqueued.twice.with(subscription:)
    end

    it "creates a new subscription" do
      expect(result).to be_success
      expect(result.subscription.id).not_to eq(subscription.id)
      expect(result.subscription).to be_active
      expect(result.subscription.name).to eq(subscription_name)
      expect(result.subscription.plan.id).to eq(plan.id)
      expect(result.subscription.previous_subscription_id).to eq(subscription.id)
      expect(result.subscription.subscription_at).to eq(subscription.subscription_at)
      expect(result.subscription.payment_method_id).to eq(nil)
      expect(result.subscription.payment_method_type).to eq("provider")
    end

    context "when subscription has consolidate_invoice disabled" do
      let(:subscription) do
        create(
          :subscription,
          customer:,
          plan: old_plan,
          status: :active,
          subscription_at: Time.current,
          started_at: Time.current,
          external_id: SecureRandom.uuid,
          consolidate_invoice: false
        )
      end

      it "preserves consolidate_invoice on the new subscription" do
        expect(result).to be_success
        expect(result.subscription.consolidate_invoice).to be(false)
      end

      context "when params override consolidate_invoice to true" do
        let(:params) { {name: subscription_name, consolidate_invoice: true} }

        it "applies the override on the new subscription" do
          expect(result).to be_success
          expect(result.subscription.consolidate_invoice).to be(true)
        end
      end
    end

    context "with payment method" do
      let(:payment_method) { create(:payment_method, organization: subscription.organization, customer: subscription.customer) }
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

      it "creates a new subscription" do
        expect(result).to be_success
        expect(result.subscription.id).not_to eq(subscription.id)
        expect(result.subscription).to be_active
        expect(result.subscription.name).to eq(subscription_name)
        expect(result.subscription.plan.id).to eq(plan.id)
        expect(result.subscription.previous_subscription_id).to eq(subscription.id)
        expect(result.subscription.subscription_at).to eq(subscription.subscription_at)
        expect(result.subscription.payment_method_id).to eq(payment_method.id)
        expect(result.subscription.payment_method_type).to eq("provider")
      end
    end

    context "when new plan has fixed charges" do
      let(:fixed_charge_1) { create(:fixed_charge, plan:) }
      let(:fixed_charge_2) { create(:fixed_charge, plan:) }

      before do
        fixed_charge_1
        fixed_charge_2
      end

      it "creates fixed charge events for the new subscription" do
        expect { result }.to change(FixedChargeEvent, :count).by(2)
        expect(result.subscription.fixed_charge_events.pluck(:fixed_charge_id, :timestamp))
          .to match_array(
            [
              [fixed_charge_1.id, be_within(1.second).of(Time.current)],
              [fixed_charge_2.id, be_within(1.second).of(Time.current)]
            ]
          )
      end
    end

    context "when current subscription is pending" do
      before { subscription.pending! }

      it "returns existing subscription with updated attributes" do
        expect(result).to be_success
        expect(result.subscription.id).to eq(subscription.id)
        expect(result.subscription.plan_id).to eq(plan.id)
        expect(result.subscription.name).to eq(subscription_name)
      end

      context "with activation_rules in params" do
        let(:params) do
          {
            name: subscription_name,
            activation_rules: [{type: "payment", timeout_hours: 48}]
          }
        end

        it "applies the activation rules to the current subscription" do
          expect(result).to be_success

          rules = subscription.reload.activation_rules
          expect(rules.count).to eq(1)
          expect(rules.first).to be_inactive
          expect(rules.first.timeout_hours).to eq(48)
        end

        it "still updates the pending subscription's plan and name" do
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

    context "with activation_rules in params" do
      let(:params) do
        {
          name: subscription_name,
          activation_rules: [{type: "payment", timeout_hours: 48}]
        }
      end

      context "when the plan is pay-in-advance" do
        let(:plan) { create(:plan, amount_cents: 200, organization:, pay_in_advance: true) }

        it "keeps the current subscription active" do
          result
          expect(subscription.reload).to be_active
        end

        it "creates the new subscription as incomplete" do
          expect(result).to be_success
          expect(result.subscription).to be_incomplete
          expect(result.subscription.previous_subscription_id).to eq(subscription.id)
          expect(result.subscription.activation_rules.pending.count).to eq(1)
        end

        it "sends the subscription.incomplete webhook" do
          result
          expect(SendWebhookJob).to have_been_enqueued.with("subscription.incomplete", result.subscription)
        end

        it "does not fire upgrade-completion webhooks" do
          result
          expect(SendWebhookJob).not_to have_been_enqueued.with("subscription.terminated", subscription)
          expect(SendWebhookJob).not_to have_been_enqueued.with("subscription.started", result.subscription)
        end

        it "enqueues BillSubscriptionJob for the incomplete subscription with skip_charges" do
          new_subscription = result.subscription

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([new_subscription], anything, invoicing_reason: :upgrading, skip_charges: true)
        end

        context "with a pending next_subscription" do
          let(:pending_next) do
            create(:subscription, status: :pending, previous_subscription: subscription, organization:, customer:)
          end

          before { pending_next }

          it "cancels the pending next_subscription before gating" do
            expect { result }.to change { pending_next.reload.status }.from("pending").to("canceled")
          end
        end
      end

      context "when the plan has no upfront billing" do
        let(:plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: false) }

        it "marks the activation rule as not_applicable" do
          expect(result).to be_success
          expect(result.subscription.activation_rules.not_applicable.count).to eq(1)
        end

        it "runs the existing immediate-upgrade flow" do
          result
          expect(subscription.reload).to be_terminated
          expect(result.subscription).to be_active
        end
      end
    end

    context "when old subscription is payed in arrear" do
      let(:old_plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: false) }

      it "enqueues a job to bill the existing subscription" do
        expect { result }.to have_enqueued_job(BillSubscriptionJob)
      end
    end

    context "when old subscription was payed in advance" do
      let(:creation_time) { Time.current.beginning_of_month - 1.month }
      let(:date_service) do
        Subscriptions::DatesService.new_instance(
          subscription,
          Time.current.beginning_of_month,
          current_usage: false
        )
      end

      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          invoice:,
          subscription:,
          recurring: true,
          from_datetime: date_service.from_datetime,
          to_datetime: date_service.to_datetime,
          charges_from_datetime: date_service.charges_from_datetime,
          charges_to_datetime: date_service.charges_to_datetime
        )
      end

      let(:invoice) do
        create(
          :invoice,
          customer:,
          currency:,
          sub_total_excluding_taxes_amount_cents: 100,
          fees_amount_cents: 100,
          taxes_amount_cents: 20,
          total_amount_cents: 120
        )
      end

      let(:last_subscription_fee) do
        create(
          :fee,
          subscription:,
          invoice:,
          amount_cents: 100,
          taxes_amount_cents: 20,
          invoiceable_type: "Subscription",
          invoiceable_id: subscription.id,
          taxes_rate: 20
        )
      end

      let(:subscription) do
        create(
          :subscription,
          customer:,
          plan: old_plan,
          status: :active,
          subscription_at: creation_time,
          started_at: creation_time,
          external_id: SecureRandom.uuid,
          billing_time: "anniversary"
        )
      end

      let(:old_plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: true) }

      before do
        invoice_subscription
        last_subscription_fee
      end

      it "creates a credit note for the remaining days" do
        expect { result }.to change(CreditNote, :count)
      end
    end

    context "when new subscription is pay in advance" do
      let(:plan) { create(:plan, amount_cents: 200, organization:, pay_in_advance: true) }

      it "includes new subscription in BillSubscriptionJob" do
        new_subscription = result.subscription

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription, new_subscription], kind_of(Integer), invoicing_reason: :upgrading)
      end
    end

    context "when new subscription is pay in arrears with pay in advance fixed charges" do
      let(:plan) { create(:plan, amount_cents: 200, organization:, pay_in_advance: false) }
      let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance: true) }

      before { fixed_charge }

      it "includes new subscription in BillSubscriptionJob" do
        new_subscription = result.subscription

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription, new_subscription], kind_of(Integer), invoicing_reason: :upgrading)
      end
    end

    context "when new subscription is pay in arrears without pay in advance fixed charges" do
      let(:plan) { create(:plan, amount_cents: 200, organization:, pay_in_advance: false) }

      it "does not include new subscription in BillSubscriptionJob" do
        result.subscription

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], kind_of(Integer), invoicing_reason: :upgrading)
      end
    end

    context "when new subscription is pay in advance and has trial period" do
      let(:plan) { create(:plan, amount_cents: 200, organization:, pay_in_advance: true, trial_period: 3) }

      context "without pay in advance fixed charges" do
        it "does not include new subscription in BillSubscriptionJob" do
          result.subscription

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], kind_of(Integer), invoicing_reason: :upgrading)
        end
      end

      context "with pay in advance fixed charges" do
        let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance: true) }

        before { fixed_charge }

        it "includes new subscription in BillSubscriptionJob for fixed charges" do
          new_subscription = result.subscription

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription, new_subscription], kind_of(Integer), invoicing_reason: :upgrading)
        end
      end
    end

    context "with pending next subscription" do
      let(:next_subscription) do
        create(
          :subscription,
          status: :pending,
          previous_subscription: subscription,
          organization:,
          customer:
        )
      end

      before { next_subscription }

      it "canceled the next subscription" do
        expect(result).to be_success
        expect(next_subscription.reload).to be_canceled
      end
    end

    describe "billing entity binding" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:other_entity) { create(:billing_entity, organization:) }

      context "when multi_entity_billing flag is OFF" do
        it "carries over the current subscription's billing_entity_id even without params" do
          subscription.update!(billing_entity:)

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(billing_entity.id)
        end

        it "ignores billing_entity_code in params but still carries over" do
          subscription.update!(billing_entity:)
          params[:billing_entity_code] = other_entity.code

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(billing_entity.id)
        end

        it "persists nil when current subscription has no billing entity binding" do
          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to be_nil
        end
      end

      context "when multi_entity_billing flag is ON" do
        before { organization.enable_feature_flag!(:multi_entity_billing) }

        it "carries over the current subscription's billing_entity_id when no param is provided" do
          subscription.update!(billing_entity:)

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(billing_entity.id)
        end

        it "persists nil when no param and current subscription is unbound" do
          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to be_nil
        end

        it "binds to billing_entity_code from params over the current binding" do
          subscription.update!(billing_entity:)
          params[:billing_entity_code] = other_entity.code

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(other_entity.id)
        end

        it "binds to billing_entity_id from params over the current binding" do
          subscription.update!(billing_entity:)
          params[:billing_entity_id] = other_entity.id

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(other_entity.id)
        end

        it "fails with billing_entity_not_found when billing_entity_id is unknown" do
          params[:billing_entity_id] = SecureRandom.uuid

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("billing_entity_not_found")
        end

        it "fails with billing_entity_not_found when billing_entity_code is unknown" do
          params[:billing_entity_code] = "unknown-entity-code"

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("billing_entity_not_found")
        end

        it "prefers billing_entity_id over billing_entity_code when both are provided" do
          params[:billing_entity_id] = billing_entity.id
          params[:billing_entity_code] = other_entity.code

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(billing_entity.id)
        end
      end

      context "when bill_subscriptions runs after the upgrade" do
        let(:plan) { create(:plan, amount_cents: 200, organization:, pay_in_advance: true) }

        before { organization.enable_feature_flag!(:multi_entity_billing) }

        it "carries the current subscription's entity into termination and new-period billing context" do
          subscription.update!(billing_entity:)

          new_subscription = result.subscription

          expect(subscription.reload.billing_entity_id).to eq(billing_entity.id)
          expect(new_subscription.billing_entity_id).to eq(billing_entity.id)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription, new_subscription], kind_of(Integer), invoicing_reason: :upgrading)
        end

        it "routes the new-period billing to the override entity when params specify one" do
          subscription.update!(billing_entity:)
          params[:billing_entity_code] = other_entity.code

          new_subscription = result.subscription

          expect(subscription.reload.billing_entity_id).to eq(billing_entity.id)
          expect(new_subscription.billing_entity_id).to eq(other_entity.id)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription, new_subscription], kind_of(Integer), invoicing_reason: :upgrading)
        end
      end
    end
  end
end
