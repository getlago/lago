# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::CreateService do
  subject(:create_service) { described_class.new(customer:, plan:, params:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, amount_cents: 100, organization:, amount_currency: "EUR") }
  let(:customer) { create(:customer, organization:, currency: "EUR") }

  let(:external_id) { SecureRandom.uuid }
  let(:billing_time) { "anniversary" }
  let(:subscription_at) { nil }
  let(:external_customer_id) { customer.external_id }
  let(:plan_code) { plan.code }
  let(:subscription_id) { nil }
  let(:name) { "invoice display name" }

  let(:params) do
    {
      external_customer_id:,
      plan_code:,
      name:,
      external_id:,
      billing_time:,
      subscription_at:,
      subscription_id:
    }
  end

  describe "#call" do
    it "creates a subscription with subscription date set to current date" do
      result = create_service.call

      expect(result).to be_success

      subscription = result.subscription
      expect(subscription.customer_id).to eq(customer.id)
      expect(subscription.plan_id).to eq(plan.id)
      expect(subscription.started_at).to be_present
      expect(subscription.subscription_at).to be_present
      expect(subscription.name).to eq("invoice display name")
      expect(subscription).to be_active
      expect(subscription.external_id).to eq(external_id)
      expect(subscription).to be_anniversary
      expect(subscription.lifetime_usage).to be_present
      expect(subscription.lifetime_usage.recalculate_invoiced_usage).to eq(true)
      expect(subscription.lifetime_usage.recalculate_current_usage).to eq(false)
      expect(subscription.payment_method_id).to eq(nil)
      expect(subscription.payment_method_type).to eq("provider")
    end

    context "when payment method is attached" do
      let(:payment_method) { create(:payment_method, organization:, customer:) }
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          payment_method: {
            payment_method_id: payment_method.id,
            payment_method_type: "provider"
          }
        }
      end

      it "creates a subscription" do
        result = create_service.call

        expect(result).to be_success

        subscription = result.subscription
        expect(subscription.customer_id).to eq(customer.id)
        expect(subscription.plan_id).to eq(plan.id)
        expect(subscription).to be_active
        expect(subscription.external_id).to eq(external_id)
        expect(subscription.payment_method_id).to eq(payment_method.id)
        expect(subscription.payment_method_type).to eq("provider")
      end
    end

    context "when plan has fixed charges" do
      let(:fixed_charge_1) { create(:fixed_charge, plan:) }
      let(:fixed_charge_2) { create(:fixed_charge, plan:) }

      before do
        fixed_charge_1
        fixed_charge_2
      end

      it "creates fixed charge events for the subscription" do
        result = create_service.call

        expect(result).to be_success
        expect(result.subscription).to be_active
        expect(result.subscription.fixed_charge_events.pluck(:fixed_charge_id, :timestamp))
          .to match_array(
            [
              [fixed_charge_1.id, be_within(5.seconds).of(Time.current)],
              [fixed_charge_2.id, be_within(5.seconds).of(Time.current)]
            ]
          )
      end

      context "when all fixed_charges and plan are pay in arrears and subscription is active" do
        it "does not enqueue a job to bill the subscription" do
          expect { create_service.call }.not_to have_enqueued_job(BillSubscriptionJob)
        end
      end

      context "when one of the fixed_charges is pay in advance and subscription is active" do
        let(:fixed_charge_1) { create(:fixed_charge, plan:, pay_in_advance: true) }

        it "enqueues a job to bill the subscription" do
          expect { create_service.call }.to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end
    end

    context "when subscription should sync with Hubspot" do
      let(:customer) { create(:customer, :with_hubspot_integration, organization:, currency: "EUR") }

      it "enqueues the Hubspot create job for a new subscription" do
        create_service.call
        expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob).to have_been_enqueued
      end

      it "does not enqueue Hubspot::UpdateJob (CreateJob captures the active state)" do
        create_service.call
        expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).not_to have_been_enqueued
      end

      context "when the subscription starts in the future" do
        let(:subscription_at) { Time.current + 5.days }

        it "does not sync to Hubspot while pending" do
          create_service.call
          expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob).not_to have_been_enqueued
          expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).not_to have_been_enqueued
        end
      end

      context "when the subscription is backdated" do
        let(:subscription_at) { Time.current - 5.days }

        it "enqueues the Hubspot create job" do
          create_service.call
          expect(Integrations::Aggregator::Subscriptions::Hubspot::CreateJob).to have_been_enqueued
        end
      end
    end

    it "produces an activity log" do
      subscription = create_service.call.subscription

      expect(Utils::ActivityLog).to have_produced("subscription.started").with(subscription)
    end

    context "when ending_at is passed" do
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          ending_at: Time.current.beginning_of_day + 3.months
        }
      end

      it "creates a subscription with ending_at correctly set" do
        result = create_service.call

        expect(result).to be_success

        subscription = result.subscription
        expect(subscription.ending_at).to eq(Time.current.beginning_of_day + 3.months)
      end
    end

    context "when progressive_billing_disabled is passed" do
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          progressive_billing_disabled: true
        }
      end

      it "creates a subscription with progressive_billing_disabled set to true" do
        result = create_service.call

        expect(result).to be_success
        expect(result.subscription.progressive_billing_disabled).to be(true)
      end
    end

    context "when consolidate_invoice is not passed" do
      it "defaults to true on the created subscription" do
        result = create_service.call

        expect(result).to be_success
        expect(result.subscription.consolidate_invoice).to be(true)
      end
    end

    context "when consolidate_invoice is passed as false" do
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          consolidate_invoice: false
        }
      end

      it "creates a subscription with consolidate_invoice set to false" do
        result = create_service.call

        expect(result).to be_success
        expect(result.subscription.consolidate_invoice).to be(false)
      end
    end

    context "when customer is invalid in an api context" do
      let(:customer) do
        build(:customer, organization:, currency: "EUR", external_id: nil)
      end

      let(:params) do
        {
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:
        }
      end

      before { CurrentContext.source = "api" }

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:external_customer_id]).to eq(["value_is_mandatory"])
      end
    end

    context "when external_id is not given in an api context" do
      let(:external_id) { nil }

      before { CurrentContext.source = "api" }

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:external_id]).to eq(["value_is_mandatory"])
      end
    end

    context "when billing_time is not provided" do
      let(:billing_time) { nil }

      it "creates a calendar subscription" do
        result = create_service.call

        expect(result).to be_success
        expect(result.subscription).to be_calendar
      end

      context "when billing time is empty" do
        let(:billing_time) { "" }

        it "creates a calendar subscription" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:billing_time]).to eq(["value_is_mandatory"])
        end
      end
    end

    context "when both usage_thresholds and plan_overrides.usage_thresholds are present" do
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          usage_thresholds: [{threshold_display_name: "Threshold 1"}],
          plan_overrides: {
            usage_thresholds: [{threshold_display_name: "Override Threshold"}]
          }
        }
      end

      it "returns a validation error", :premium do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:"plan_overrides.usage_thresholds"]).to eq(["incompatible_params"])
        expect(result.error.messages[:usage_thresholds]).to eq(["incompatible_params"])
      end
    end

    context "with valid usage_thresholds", :premium do
      let(:usage_thresholds) { [{threshold_display_name: "Threshold 1"}] }
      let(:base_params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:
        }
      end

      context "when usage_thresholds is part of subscription params" do
        let(:params) do
          base_params.merge({
            usage_thresholds:
          })
        end

        it "returns a validation error" do
          allow(Subscriptions::UpdateUsageThresholdsService).to receive(:call).and_return(BaseResult.new)
          result = create_service.call

          expect(result).to be_success
          expect(Subscriptions::UpdateUsageThresholdsService).to have_received(:call).with(
            subscription: result.subscription, usage_thresholds_params: usage_thresholds, partial: false
          )
        end
      end

      context "when usage_thresholds is part of plan_overrides params" do
        let(:params) do
          base_params.merge({
            plan_overrides: {
              usage_thresholds:
            }
          })
        end

        it "returns a validation error" do
          allow(Subscriptions::UpdateUsageThresholdsService).to receive(:call).and_return(BaseResult.new)
          result = create_service.call

          expect(result).to be_success
          expect(Subscriptions::UpdateUsageThresholdsService).not_to have_received(:call)
        end
      end
    end

    context "when License is free and plan_overrides is passed" do
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          plan_overrides: {
            amount_cents: 0
          }
        }
      end

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "when License is premium and plan_overrides is passed", :premium do
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          started_at:,
          plan_overrides: {
            fixed_charges: [
              {
                id: fixed_charge2.id,
                units: 100
              }
            ]
          }
        }
      end

      let(:fixed_charge1) { create(:fixed_charge, plan:, units: 5) }
      let(:fixed_charge2) { create(:fixed_charge, plan:, units: 9) }
      let(:add_on) { create(:add_on, organization:) }
      let(:started_at) { Time.current }

      before do
        fixed_charge1
        fixed_charge2
      end

      it "creates the subscription on the parent plan and writes a units override row" do
        result = create_service.call

        expect(result).to be_success
        expect(result.subscription).to be_active
        expect(result.subscription.plan).to eq(plan)
        expect(result.subscription.plan.parent_id).to be_nil

        override = result.subscription.fixed_charge_units_overrides.sole
        expect(override.fixed_charge).to eq(fixed_charge2)
        expect(override.units).to eq(100)
      end

      it "emits fixed charge events with the override units for the active subscription" do
        result = create_service.call

        expect(result).to be_success

        subscription = result.subscription
        expect(subscription.fixed_charge_events.pluck(:fixed_charge_id, :units, :timestamp)).to contain_exactly(
          [fixed_charge1.id, 5, be_within(1.second).of(subscription.started_at)],
          [fixed_charge2.id, 100, be_within(1.second).of(subscription.started_at)]
        )
      end

      context "when subscription starts in the future" do
        let(:subscription_at) { 7.days.from_now }

        it "creates a pending subscription on the parent plan with the override row and no fixed charge events" do
          result = create_service.call

          expect(result).to be_success

          subscription = result.subscription
          expect(subscription).to be_pending
          expect(subscription.started_at).to be_nil
          expect(subscription.plan).to eq(plan)
          expect(subscription.plan.parent_id).to be_nil

          override = subscription.fixed_charge_units_overrides.sole
          expect(override.fixed_charge).to eq(fixed_charge2)
          expect(override.units).to eq(100)

          # NO fixed charge events for pending subscription
          expect(subscription.fixed_charge_events.count).to eq(0)
        end
      end

      context "when plan_overrides carries non-units fields (plan-override path)" do
        let(:params) do
          {
            external_customer_id:,
            plan_code:,
            name:,
            external_id:,
            billing_time:,
            subscription_at:,
            subscription_id:,
            started_at:,
            plan_overrides: {
              amount_cents: 12_345,
              fixed_charges: [
                {
                  id: fixed_charge2.id,
                  units: 100
                }
              ]
            }
          }
        end

        it "creates an overridden plan with overridden fixed charges and no override row" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription).to be_active
          expect(result.subscription.plan.parent_id).to eq(plan.id)
          expect(result.subscription.fixed_charge_units_overrides).to be_empty

          overridden_plan = result.subscription.plan
          expect(overridden_plan.fixed_charges.count).to eq(2)

          fc1_override = overridden_plan.fixed_charges.find_sole_by(parent_id: fixed_charge1.id)
          fc2_override = overridden_plan.fixed_charges.find_sole_by(parent_id: fixed_charge2.id)

          expect(fc1_override.units).to eq(5) # default carried over
          expect(fc2_override.units).to eq(100) # overridden

          expect(result.subscription.fixed_charge_events.pluck(:fixed_charge_id, :units, :timestamp)).to contain_exactly(
            [fc1_override.id, 5, be_within(1.second).of(result.subscription.started_at)],
            [fc2_override.id, 100, be_within(1.second).of(result.subscription.started_at)]
          )
        end

        context "when subscription starts in the future" do
          let(:subscription_at) { 7.days.from_now }

          it "creates a pending subscription with the overridden plan and no events" do
            result = create_service.call

            expect(result).to be_success

            subscription = result.subscription
            expect(subscription).to be_pending
            expect(subscription.started_at).to be_nil
            expect(subscription.plan.parent_id).to eq(plan.id)

            overridden_plan = subscription.plan
            expect(overridden_plan.fixed_charges.count).to eq(2)
            expect(overridden_plan.fixed_charges.find_sole_by(parent_id: fixed_charge2.id).units).to eq(100)

            expect(subscription.fixed_charge_events.count).to eq(0)
          end
        end
      end

      context "when the target plan is itself an override" do
        let(:parent_plan) { create(:plan, organization:, amount_cents: 100, amount_currency: "EUR") }
        let(:plan) { create(:plan, organization:, parent: parent_plan) }

        it "routes through the plan-override path rather than the units-only branch" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.fixed_charge_units_overrides).to be_empty
        end
      end

      context "when an entry references a fixed_charge id not on the plan" do
        let(:other_plan) { create(:plan, organization:) }
        let(:foreign_fixed_charge) { create(:fixed_charge, plan: other_plan) }
        let(:params) do
          {
            external_customer_id:,
            plan_code:,
            name:,
            external_id:,
            billing_time:,
            subscription_at:,
            subscription_id:,
            started_at:,
            plan_overrides: {fixed_charges: [{id: foreign_fixed_charge.id, units: 100}]}
          }
        end

        before { foreign_fixed_charge }

        it "fails with a not found error for the fixed charge" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("fixed_charge")
        end

        it "rolls back without creating a subscription or override row" do
          expect { create_service.call }
            .to not_change(Subscription, :count)
            .and not_change(::Subscription::FixedChargeUnitsOverride, :count)
        end
      end

      context "with invoice custom sections" do
        let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }

        let(:params) do
          {
            external_customer_id:,
            plan_code:,
            name:,
            external_id:,
            invoice_custom_section: {invoice_custom_section_codes: [section_1.code]}
          }
        end

        before {
          CurrentContext.source = "api"
          section_1
        }

        it "attach to subscription" do
          result = create_service.call

          expect(result).to be_success

          subscription = result.subscription.reload
          expect(subscription.applied_invoice_custom_sections.count).to be(1)
          expect(subscription.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id)
        end
      end
    end

    context "when customer does not exists in API context" do
      let(:customer) { Customer.new(organization:, external_id: SecureRandom.uuid, billing_entity: organization.default_billing_entity) }

      before { CurrentContext.source = "api" }

      it "creates the customer" do
        result = create_service.call

        expect(result).to be_success

        subscription = result.subscription
        expect(subscription.customer.external_id).to eq(customer.external_id)
        expect(subscription.plan_id).to eq(plan.id)
        expect(subscription.started_at).to be_present
        expect(subscription.subscription_at).to be_present
        expect(subscription).to be_active
      end

      context "when in graphql context" do
        let(:customer) { nil }
        let(:external_customer_id) { nil }

        before { CurrentContext.source = "graphql" }

        it "returns a customer_not_found error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("customer_not_found")
        end
      end
    end

    context "when plan is pay_in_advance" do
      let(:plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: true) }

      context "when subscription_at is current date" do
        it "enqueues a job to bill the subscription" do
          expect { create_service.call }.to have_enqueued_job(BillSubscriptionJob)
        end
      end

      context "when subscription_at is in the future" do
        let(:subscription_at) { Time.current + 5.days }

        it "does not enqueue a job to bill the subscription" do
          expect { create_service.call }.not_to have_enqueued_job(BillSubscriptionJob)
        end
      end

      context "when subscription_at is current date but there is a trial period" do
        let(:plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: true, trial_period: 10) }

        it "does not enqueue a job to bill the subscription" do
          expect { create_service.call }.not_to have_enqueued_job(BillSubscriptionJob)
        end

        context "when plan has pay in advance fixed charges" do
          let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance: true) }

          before { fixed_charge }

          it "does not enqueue a job to bill the subscription" do
            expect { create_service.call }.not_to have_enqueued_job(BillSubscriptionJob)
          end

          it "enqueues a job to bill the pay in advance fixed charges even during trial" do
            expect { create_service.call }.to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
          end
        end
      end

      context "when plan has pay in advance fixed charges" do
        let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance: true) }

        before { fixed_charge }

        it "enqueues a job to bill the subscription" do
          expect { create_service.call }.to have_enqueued_job(BillSubscriptionJob)
        end

        it "does not enqueue a job to bill the pay in advance fixed charges" do
          expect { create_service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end
    end

    context "when plan is not pay_in_advance, subscription_at is current date and there are fixed charges" do
      let(:plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: false) }
      let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance:) }

      before do
        fixed_charge
      end

      context "when at least one fixed charge is pay_in_advance" do
        let(:pay_in_advance) { true }

        it "does not queue a job to bill the subscription" do
          expect { create_service.call }.not_to have_enqueued_job(BillSubscriptionJob)
        end

        it "enqueues a job to bill the the pay in advance fixed charges" do
          expect { create_service.call }.to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end

        context "when plan has a trial period" do
          let(:plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: true, trial_period: 10) }

          it "does not queue a job to bill the subscription" do
            expect { create_service.call }.not_to have_enqueued_job(BillSubscriptionJob)
          end

          it "enqueues a job to bill the pay in advance fixed charges even during trial" do
            expect { create_service.call }.to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
          end
        end
      end

      context "when all fixed charges are not pay_in_advance" do
        let(:pay_in_advance) { false }

        it "does not enqueue a job to bill the subscription" do
          expect { create_service.call }.not_to have_enqueued_job(BillSubscriptionJob)
        end

        it "does not enqueue a job to bill fixed charges" do
          expect { create_service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end
    end

    context "when customer is missing" do
      let(:customer) { nil }
      let(:external_customer_id) { nil }

      it "returns a customer_not_found error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("customer_not_found")
      end
    end

    context "when plan doest not exists" do
      let(:plan) { nil }
      let(:plan_code) { nil }

      it "returns a plan_not_found error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.message).to eq("plan_not_found")
      end
    end

    context "when subscription_at is given and is invalid" do
      let(:subscription_at) { "2022-99-99T00:00:00Z" }

      it "returns invalid_at error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:subscription_at]).to eq(["invalid_date"])
      end
    end

    context "when subscription_at is given and is in the future" do
      let(:subscription_at) { Time.current + 5.days }

      it "creates a pending subscription" do
        result = create_service.call

        expect(result).to be_success

        subscription = result.subscription
        expect(subscription.customer_id).to eq(customer.id)
        expect(subscription.plan_id).to eq(plan.id)
        expect(subscription.started_at).not_to be_present
        expect(subscription.subscription_at.to_s).to eq(subscription_at.to_s)
        expect(subscription.name).to eq("invoice display name")
        expect(subscription).to be_pending
        expect(subscription.external_id).to eq(external_id)
        expect(subscription).to be_anniversary
        expect(subscription.lifetime_usage).not_to be_present
      end

      context "when plan has fixed charges" do
        let(:fixed_charge_1) { create(:fixed_charge, plan:) }
        let(:fixed_charge_2) { create(:fixed_charge, plan:) }

        before do
          fixed_charge_1
          fixed_charge_2
        end

        it "does not create fixed charge events for the subscription" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription).to be_pending
          expect(result.subscription.fixed_charge_events.count).to eq(0)
        end
      end
    end

    context "when subscription_at is given and is in the past" do
      let(:subscription_at) { Time.current - 5.days }

      it "creates a active subscription" do
        result = create_service.call

        expect(result).to be_success

        subscription = result.subscription
        expect(subscription.customer_id).to eq(customer.id)
        expect(subscription.plan_id).to eq(plan.id)
        expect(subscription.started_at.to_s).to eq(subscription_at.to_s)
        expect(subscription.subscription_at.to_s).to eq(subscription_at.to_s)
        expect(subscription.name).to eq("invoice display name")
        expect(subscription).to be_active
        expect(subscription.external_id).to eq(external_id)
        expect(subscription).to be_anniversary
        expect(subscription.lifetime_usage).to be_present
        expect(subscription.lifetime_usage.recalculate_invoiced_usage).to eq(true)
        expect(subscription.lifetime_usage.recalculate_current_usage).to eq(false)
      end

      context "when plan has pay in advance fixed charges" do
        let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance: true) }

        before { fixed_charge }

        it "does not enqueue a job to bill the pay in advance fixed charges" do
          expect { create_service.call }.not_to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
        end
      end
    end

    context "when subscription_at is earlier today" do
      let(:now) { Time.zone.local(2026, 5, 20, 14, 30) }
      let(:subscription_at) { now.beginning_of_day }

      around { |example| travel_to(now) { example.run } }

      it "sets started_at to subscription_at so events in the gap are included in usage" do
        result = create_service.call

        expect(result).to be_success

        subscription = result.subscription
        expect(subscription).to be_active
        expect(subscription.started_at).to eq(subscription_at)
        expect(subscription.subscription_at).to eq(subscription_at)
      end
    end

    context "when billing_time is invalid" do
      let(:billing_time) { :foo }

      it "fails" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages.keys).to eq([:billing_time])
      end
    end

    context "with invalid payment method" do
      let(:payment_method) { create(:payment_method, organization:, customer:) }
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          payment_method: payment_method_params
        }
      end

      before { payment_method }

      context "when type is invalid" do
        let(:payment_method_params) do
          {
            payment_method_id: payment_method.id,
            payment_method_type: "invalid"
          }
        end

        it "fails" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end

      context "when ID is invalid" do
        let(:payment_method_params) do
          {
            payment_method_id: "invalid",
            payment_method_type: "provider"
          }
        end

        it "fails" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:payment_method]).to eq(["invalid_payment_method"])
        end
      end
    end

    context "when an active subscription already exists" do
      let(:subscription) do
        create(
          :subscription,
          customer:,
          plan: old_plan,
          status: :active,
          subscription_at: Time.current,
          started_at: Time.current,
          external_id:
        )
      end

      let(:old_plan) { plan }

      before do
        CurrentContext.source = "api"
        subscription
      end

      context "when external_id is given" do
        it "returns existing subscription" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.id).to eq(subscription.id)
        end
      end

      context "when subscription_id is given" do
        let(:subscription_id) { subscription.id }

        before { CurrentContext.source = "graphql" }

        it "returns existing subscription" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.id).to eq(subscription.id)
        end
      end

      context "when new plan has different currency than the old plan" do
        let(:plan) { create(:plan, amount_cents: 200, organization:, amount_currency: "USD") }

        it "fails" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages.keys).to include(:currency)
          expect(result.error.messages[:currency]).to include("currencies_does_not_match")
        end
      end

      context "when plan is not the same" do
        context "when we upgrade the plan" do
          let(:customer) { create(:customer, :with_hubspot_integration, organization:, currency: "EUR") }
          let(:plan) { create(:plan, amount_cents: 200, organization:) }
          let(:old_plan) { create(:plan, amount_cents: 100, organization:) }
          let(:name) { "invoice display name new" }

          before do
            subscription.mark_as_active!
          end

          it "terminates the existing subscription" do
            expect { create_service.call }.to change { subscription.reload.status }.from("active").to("terminated")
          end

          it "moves the lifetime_usage to the new subscription" do
            lifetime_usage = subscription.lifetime_usage
            result = create_service.call
            expect(result.subscription.lifetime_usage).to eq(lifetime_usage.reload)
            expect(subscription.reload.lifetime_usage).to be_nil
          end

          it "sends terminated and started subscription webhooks" do
            result = create_service.call
            expect(SendWebhookJob).to have_been_enqueued.with("subscription.terminated", subscription)
            expect(SendWebhookJob).to have_been_enqueued.with("subscription.started", result.subscription)
          end

          it "enqueues the Hubspot update job" do
            create_service.call
            expect(Integrations::Aggregator::Subscriptions::Hubspot::UpdateJob).to have_been_enqueued.twice.with(subscription:)
          end

          it "creates a new subscription" do
            result = create_service.call

            expect(result).to be_success
            expect(result.subscription.id).not_to eq(subscription.id)
            expect(result.subscription).to be_active
            expect(result.subscription.name).to eq("invoice display name new")
            expect(result.subscription.plan.id).to eq(plan.id)
            expect(result.subscription.previous_subscription_id).to eq(subscription.id)
            expect(result.subscription.subscription_at).to eq(subscription.subscription_at)
            expect(result.subscription.payment_method_id).to eq(nil)
            expect(result.subscription.payment_method_type).to eq("provider")
          end

          context "when plan has fixed charges" do
            let(:fixed_charge_1) { create(:fixed_charge, plan:) }
            let(:fixed_charge_2) { create(:fixed_charge, plan:) }

            before do
              fixed_charge_1
              fixed_charge_2
            end

            it "creates fixed charge events for the subscription" do
              freeze_time do
                result = create_service.call

                expect(result).to be_success
                expect(result.subscription).to be_active
                expect(result.subscription.fixed_charge_events.pluck(:fixed_charge_id, :timestamp))
                  .to match_array(
                    [
                      [fixed_charge_1.id, be_within(1.second).of(Time.current)],
                      [fixed_charge_2.id, be_within(1.second).of(Time.current)]
                    ]
                  )
              end
            end
          end

          context "when payment method is attached" do
            let(:payment_method) { create(:payment_method, organization:, customer:) }
            let(:params) do
              {
                external_customer_id:,
                plan_code:,
                name:,
                external_id:,
                billing_time:,
                subscription_at:,
                subscription_id:,
                payment_method: {
                  payment_method_id: payment_method.id,
                  payment_method_type: "provider"
                }
              }
            end

            it "creates a new subscription" do
              result = create_service.call

              expect(result).to be_success
              expect(result.subscription.id).not_to eq(subscription.id)
              expect(result.subscription).to be_active
              expect(result.subscription.name).to eq("invoice display name new")
              expect(result.subscription.plan.id).to eq(plan.id)
              expect(result.subscription.previous_subscription_id).to eq(subscription.id)
              expect(result.subscription.subscription_at).to eq(subscription.subscription_at)
              expect(result.subscription.payment_method_id).to eq(payment_method.id)
              expect(result.subscription.payment_method_type).to eq("provider")
            end
          end

          context "when subscription upgrade fails" do
            let(:result_failure) do
              BaseService::Result.new.validation_failure!(
                errors: {billing_time: ["value_is_invalid"]}
              )
            end

            before do
              allow(Subscriptions::PlanUpgradeService)
                .to receive(:call)
                .and_return(result_failure)
            end

            it "returns an error" do
              result = create_service.call

              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::ValidationFailure)
              expect(result.error.messages).to eq({billing_time: ["value_is_invalid"]})
            end
          end

          context "when current subscription is pending" do
            before { subscription.pending! }

            it "returns existing subscription with updated attributes" do
              result = create_service.call

              expect(result).to be_success
              expect(result.subscription.id).to eq(subscription.id)
              expect(result.subscription.plan_id).to eq(plan.id)
              expect(result.subscription.name).to eq("invoice display name new")
            end

            context "when plan has fixed charges" do
              let(:fixed_charge_1) { create(:fixed_charge, plan:) }
              let(:fixed_charge_2) { create(:fixed_charge, plan:) }

              before do
                fixed_charge_1
                fixed_charge_2
              end

              it "does not create fixed charge events when updating a pending subscription" do
                freeze_time do
                  result = create_service.call

                  expect(result).to be_success
                  expect(result.subscription).to be_pending
                  expect(result.subscription.fixed_charge_events.count).to eq(0)
                end
              end
            end
          end

          context "when old subscription is payed in arrear" do
            let(:old_plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: false) }

            it "enqueues a job to bill the existing subscription" do
              expect { create_service.call }.to have_enqueued_job(BillSubscriptionJob)
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
                currency: "EUR",
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
                external_id:,
                billing_time: "anniversary"
              )
            end

            let(:old_plan) { create(:plan, amount_cents: 100, organization:, pay_in_advance: true) }

            before do
              invoice_subscription
              last_subscription_fee
            end

            it "creates a credit note for the remaining days" do
              expect { create_service.call }.to change(CreditNote, :count)
            end
          end

          context "when new subscription is payed in advance" do
            let(:plan) { create(:plan, amount_cents: 200, organization:, pay_in_advance: true) }

            it "enqueues a job to bill the existing subscription" do
              expect { create_service.call }.to have_enqueued_job(BillSubscriptionJob)
            end
          end

          context "with pending next subscription" do
            let(:next_subscription) do
              create(
                :subscription,
                status: :pending,
                previous_subscription: subscription,
                organization: subscription.organization
              )
            end

            before { next_subscription }

            it "canceled the next subscription" do
              result = create_service.call

              expect(result).to be_success
              expect(next_subscription.reload).to be_canceled
            end
          end

          context "with incomplete next subscription" do
            let(:next_plan) { create(:plan, organization:) }

            before do
              create(
                :subscription,
                :incomplete,
                customer:,
                plan: next_plan,
                organization:,
                previous_subscription: subscription,
                external_id: subscription.external_id
              )
            end

            it "returns subscription_incomplete error" do
              result = create_service.call

              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::ValidationFailure)
              expect(result.error.messages[:subscription]).to eq(["subscription_incomplete"])
            end
          end
        end

        context "when we downgrade the plan" do
          before do
            subscription.mark_as_active!
          end

          let(:plan) { create(:plan, amount_cents: 50, organization:) }
          let(:old_plan) { create(:plan, amount_cents: 100, organization:) }
          let(:name) { "invoice display name new" }

          it "creates a new subscription" do
            result = create_service.call

            expect(result).to be_success

            next_subscription = result.subscription.next_subscription
            expect(next_subscription.id).not_to eq(subscription.id)
            expect(next_subscription).to be_pending
            expect(next_subscription.name).to eq("invoice display name new")
            expect(next_subscription.plan_id).to eq(plan.id)
            expect(next_subscription.subscription_at).to eq(subscription.subscription_at)
            expect(next_subscription.previous_subscription).to eq(subscription)
            expect(next_subscription.ending_at).to eq(subscription.ending_at)
            expect(next_subscription.lifetime_usage).to be_nil
            expect(next_subscription.payment_method_id).to be_nil
            expect(next_subscription.payment_method_type).to eq("provider")
          end

          it "sends updated subscription webhook" do
            create_service.call
            expect(SendWebhookJob).to have_been_enqueued.with("subscription.updated", subscription)
          end

          it "produces an activity log" do
            create_service.call
            expect(Utils::ActivityLog).to have_produced("subscription.updated").with(subscription)
          end

          it "keeps the current subscription" do
            result = create_service.call

            expect(result.subscription.id).to eq(subscription.id)
            expect(result.subscription).to be_active
            expect(result.subscription.next_subscription).to be_present
            expect(result.subscription.lifetime_usage).to be_present
          end

          context "with invoice custom sections" do
            let(:section_1) { create(:invoice_custom_section, organization:, code: "section_code_1") }

            let(:params) do
              {
                external_customer_id:,
                plan_code:,
                name:,
                external_id:,
                billing_time:,
                subscription_at:,
                subscription_id:,
                invoice_custom_section: {invoice_custom_section_codes: [section_1.code]}
              }
            end

            before { section_1 }

            it "attach to new subscription" do
              result = create_service.call

              expect(result).to be_success

              next_subscription = result.subscription.next_subscription.reload
              expect(next_subscription.applied_invoice_custom_sections.count).to be(1)
              expect(next_subscription.applied_invoice_custom_sections.pluck(:invoice_custom_section_id)).to include(section_1.id)
            end
          end

          context "when current subscription has consolidate_invoice disabled" do
            let(:subscription) do
              create(
                :subscription,
                customer:,
                plan: old_plan,
                status: :active,
                subscription_at: Time.current,
                started_at: Time.current,
                external_id:,
                consolidate_invoice: false
              )
            end

            it "preserves consolidate_invoice on the next subscription" do
              result = create_service.call

              expect(result).to be_success
              expect(result.subscription.next_subscription.consolidate_invoice).to be(false)
            end

            context "when params override consolidate_invoice to true" do
              let(:params) do
                {
                  external_customer_id:,
                  plan_code:,
                  name:,
                  external_id:,
                  billing_time:,
                  subscription_at:,
                  subscription_id:,
                  consolidate_invoice: true
                }
              end

              it "applies the override on the next subscription" do
                result = create_service.call

                expect(result).to be_success
                expect(result.subscription.next_subscription.consolidate_invoice).to be(true)
              end
            end
          end

          context "when plan has fixed charges" do
            let(:fixed_charge_1) { create(:fixed_charge, plan:) }
            let(:fixed_charge_2) { create(:fixed_charge, plan:) }

            before do
              fixed_charge_1
              fixed_charge_2
            end

            it "creates fixed charge events for the new subscription" do
              result = create_service.call

              expect(result).to be_success

              next_subscription = result.subscription.next_subscription
              expect(next_subscription).to be_pending
              expect(next_subscription.fixed_charge_events.count).to eq(0)
            end
          end

          context "when payment method is attached" do
            let(:payment_method) { create(:payment_method, organization:, customer:) }
            let(:params) do
              {
                external_customer_id:,
                plan_code:,
                name:,
                external_id:,
                billing_time:,
                subscription_at:,
                subscription_id:,
                payment_method: {
                  payment_method_id: payment_method.id,
                  payment_method_type: "provider"
                }
              }
            end

            it "creates a new subscription" do
              result = create_service.call

              expect(result).to be_success

              next_subscription = result.subscription.next_subscription
              expect(next_subscription.id).not_to eq(subscription.id)
              expect(next_subscription).to be_pending
              expect(next_subscription.name).to eq("invoice display name new")
              expect(next_subscription.plan_id).to eq(plan.id)
              expect(next_subscription.subscription_at).to eq(subscription.subscription_at)
              expect(next_subscription.previous_subscription).to eq(subscription)
              expect(next_subscription.ending_at).to eq(subscription.ending_at)
              expect(next_subscription.lifetime_usage).to be_nil
              expect(next_subscription.payment_method_id).to eq(payment_method.id)
              expect(next_subscription.payment_method_type).to eq("provider")
            end
          end

          context "when ending_at is overridden" do
            let(:params) do
              {
                external_customer_id:,
                plan_code:,
                name:,
                external_id:,
                billing_time:,
                subscription_at:,
                subscription_id:,
                ending_at: Time.current.beginning_of_day + 3.months
              }
            end

            it "creates a new subscription with correctly set ending_at" do
              result = create_service.call

              expect(result).to be_success

              next_subscription = result.subscription.next_subscription
              expect(next_subscription.ending_at).to eq(Time.current.beginning_of_day + 3.months)
            end
          end

          context "when current subscription is pending" do
            before { subscription.pending! }

            it "returns existing subscription with updated attributes" do
              result = create_service.call

              expect(result).to be_success
              expect(result.subscription.id).to eq(subscription.id)
              expect(result.subscription.plan_id).to eq(plan.id)
              expect(result.subscription.name).to eq("invoice display name new")
            end
          end

          context "with pending next subscription" do
            let(:next_subscription) do
              create(
                :subscription,
                status: :pending,
                previous_subscription: subscription,
                organization: subscription.organization
              )
            end

            before { next_subscription }

            it "canceled the next subscription" do
              result = create_service.call

              expect(result).to be_success
              expect(next_subscription.reload).to be_canceled
            end
          end

          context "with incomplete next subscription" do
            let(:next_plan) { create(:plan, organization:) }

            before do
              create(
                :subscription,
                :incomplete,
                customer:,
                plan: next_plan,
                organization:,
                previous_subscription: subscription,
                external_id: subscription.external_id
              )
            end

            it "returns subscription_incomplete error" do
              result = create_service.call

              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::ValidationFailure)
              expect(result.error.messages[:subscription]).to eq(["subscription_incomplete"])
            end
          end

          context "when subscription downgrade fails" do
            let(:result_failure) do
              BaseService::Result.new.validation_failure!(
                errors: {billing_time: ["value_is_invalid"]}
              )
            end

            before do
              allow(Subscriptions::PlanDowngradeService)
                .to receive(:call)
                .and_return(result_failure)
            end

            it "returns an error" do
              result = create_service.call

              expect(result).not_to be_success
              expect(result.error).to be_a(BaseService::ValidationFailure)
              expect(result.error.messages).to eq({billing_time: ["value_is_invalid"]})
            end
          end
        end
      end
    end

    context "when existing subscription with same external_id is incomplete" do
      let(:incomplete_subscription) do
        create(:subscription, :incomplete, customer:, plan:, organization:, external_id:)
      end

      before { incomplete_subscription }

      it "returns a subscription_incomplete error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:subscription]).to eq(["subscription_incomplete"])
      end
    end

    context "when another customer in the same organization has an active subscription with the same external_id" do
      let(:other_customer) { create(:customer, organization:) }

      before do
        create(:subscription, customer: other_customer, plan:, organization:, external_id:)
      end

      it "returns an external_id already exist error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:external_id]).to eq(["value_already_exist"])
      end
    end

    context "with activation_rules" do
      let(:customer) { create(:customer, organization:, payment_provider: "stripe") }

      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          activation_rules: [{type: "payment", timeout_hours: 48}]
        }
      end

      before { create(:payment_method, customer:, organization:) }

      context "when subscription_at is in the past" do
        let(:subscription_at) { (Time.current - 5.days).iso8601 }

        it "creates active subscription without activation rules" do
          result = create_service.call

          expect(result).to be_success
          subscription = result.subscription
          expect(subscription).to be_active
          expect(subscription.activation_rules.count).to eq(0)
        end
      end

      context "when subscription_at is today" do
        let(:subscription_at) { Time.current.beginning_of_day.iso8601 }

        it "creates active subscription with not_applicable activation rules (pay-in-arrears plan)" do
          result = create_service.call

          expect(result).to be_success
          subscription = result.subscription
          expect(subscription).to be_active
          expect(subscription.activation_rules.count).to eq(1)
          expect(subscription.activation_rules.first).to be_not_applicable
        end

        context "when plan is pay in advance" do
          let(:plan) { create(:plan, amount_cents: 100, organization:, amount_currency: "EUR", pay_in_advance: true) }

          it "creates incomplete subscription with pending activation rule" do
            result = create_service.call

            expect(result).to be_success
            subscription = result.subscription
            expect(subscription).to be_incomplete
            expect(subscription.activation_rules.count).to eq(1)
            expect(subscription.activation_rules.first).to be_pending
          end

          it "enqueues BillSubscriptionJob" do
            expect { create_service.call }.to have_enqueued_job(BillSubscriptionJob)
          end

          context "when subscription_at is earlier today" do
            let(:now) { Time.zone.local(2026, 5, 20, 14, 30) }
            let(:subscription_at) { now.beginning_of_day.iso8601 }

            around { |example| travel_to(now) { example.run } }

            it "sets started_at to subscription_at on the gated incomplete subscription" do
              result = create_service.call

              expect(result).to be_success
              subscription = result.subscription
              expect(subscription).to be_incomplete
              expect(subscription.started_at).to eq(now.beginning_of_day)
            end
          end
        end

        context "when plan is pay in arrears with pay-in-advance fixed charges" do
          let(:add_on) { create(:add_on, organization:) }

          before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

          it "creates incomplete subscription with pending activation rule" do
            result = create_service.call

            expect(result).to be_success
            subscription = result.subscription
            expect(subscription).to be_incomplete
            expect(subscription.activation_rules.count).to eq(1)
            expect(subscription.activation_rules.first).to be_pending
          end

          it "enqueues CreatePayInAdvanceFixedChargesJob" do
            expect { create_service.call }.to have_enqueued_job(Invoices::CreatePayInAdvanceFixedChargesJob)
          end
        end

        context "when plan is pay in advance with trial period" do
          let(:plan) { create(:plan, amount_cents: 100, organization:, amount_currency: "EUR", pay_in_advance: true, trial_period: 30) }

          it "creates active subscription with not_applicable activation rule" do
            result = create_service.call

            expect(result).to be_success
            subscription = result.subscription
            expect(subscription).to be_active
            expect(subscription.activation_rules.count).to eq(1)
            expect(subscription.activation_rules.first).to be_not_applicable
          end

          context "when plan has pay-in-advance fixed charges" do
            let(:add_on) { create(:add_on, organization:) }

            before { create(:fixed_charge, plan:, add_on:, pay_in_advance: true) }

            it "creates incomplete subscription with pending activation rule" do
              result = create_service.call

              expect(result).to be_success
              subscription = result.subscription
              expect(subscription).to be_incomplete
              expect(subscription.activation_rules.count).to eq(1)
              expect(subscription.activation_rules.first).to be_pending
            end
          end
        end
      end

      context "when subscription_at is in the future" do
        let(:subscription_at) { (Time.current + 5.days).iso8601 }

        it "creates pending subscription with activation rules" do
          result = create_service.call

          expect(result).to be_success
          subscription = result.subscription
          expect(subscription).to be_pending
          expect(subscription.activation_rules.count).to eq(1)
          expect(subscription.activation_rules.first).to have_attributes(
            type: "payment",
            timeout_hours: 48,
            status: "inactive"
          )
        end
      end

      context "with invalid activation rule type" do
        let(:params) do
          {
            external_customer_id:,
            plan_code:,
            name:,
            external_id:,
            billing_time:,
            subscription_at:,
            subscription_id:,
            activation_rules: [{type: "unknown"}]
          }
        end

        it "returns validation error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:activation_rules]).to include("invalid_type")
        end
      end

      context "when timeout_hours is omitted" do
        let(:subscription_at) { (Time.current + 5.days).iso8601 }

        let(:params) do
          {
            external_customer_id:,
            plan_code:,
            name:,
            external_id:,
            billing_time:,
            subscription_at:,
            subscription_id:,
            activation_rules: [{type: "payment"}]
          }
        end

        it "creates activation rule with timeout_hours defaulting to 0" do
          result = create_service.call

          expect(result).to be_success
          subscription = result.subscription
          expect(subscription).to be_pending
          expect(subscription.activation_rules.count).to eq(1)
          expect(subscription.activation_rules.first).to have_attributes(
            type: "payment",
            timeout_hours: 0,
            status: "inactive"
          )
        end
      end

      context "with negative timeout_hours" do
        let(:params) do
          {
            external_customer_id:,
            plan_code:,
            name:,
            external_id:,
            billing_time:,
            subscription_at:,
            subscription_id:,
            activation_rules: [{type: "payment", timeout_hours: -1}]
          }
        end

        it "returns validation error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:timeout_hours]).to include("value_must_be_positive_or_zero")
        end
      end
    end

    context "when activation_rules is nil" do
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          activation_rules: nil
        }
      end

      it "creates subscription without activation rules" do
        result = create_service.call

        expect(result).to be_success
        expect(result.subscription.activation_rules.count).to eq(0)
      end
    end

    context "when activation_rules is empty" do
      let(:params) do
        {
          external_customer_id:,
          plan_code:,
          name:,
          external_id:,
          billing_time:,
          subscription_at:,
          subscription_id:,
          activation_rules: []
        }
      end

      it "creates subscription without activation rules" do
        result = create_service.call

        expect(result).to be_success
        expect(result.subscription.activation_rules.count).to eq(0)
      end
    end

    describe "billing entity binding" do
      let(:billing_entity) { create(:billing_entity, organization:) }

      context "when multi_entity_billing flag is OFF" do
        it "ignores billing_entity_code and persists nil" do
          params[:billing_entity_code] = billing_entity.code

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to be_nil
        end

        it "ignores billing_entity_id and persists nil" do
          params[:billing_entity_id] = billing_entity.id

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to be_nil
        end
      end

      context "when multi_entity_billing flag is ON" do
        before { organization.enable_feature_flag!(:multi_entity_billing) }

        it "persists nil when no billing entity reference is provided" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to be_nil
        end

        it "binds the subscription to the entity matched by billing_entity_id" do
          params[:billing_entity_id] = billing_entity.id

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(billing_entity.id)
        end

        it "binds the subscription to the entity matched by billing_entity_code" do
          params[:billing_entity_code] = billing_entity.code

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(billing_entity.id)
        end

        it "fails with billing_entity_not_found when billing_entity_id is unknown" do
          params[:billing_entity_id] = SecureRandom.uuid

          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("billing_entity_not_found")
        end

        it "fails with billing_entity_not_found when billing_entity_code is unknown" do
          params[:billing_entity_code] = "unknown-entity-code"

          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("billing_entity_not_found")
        end

        it "prefers billing_entity_id over billing_entity_code when both are provided" do
          other_entity = create(:billing_entity, organization:)
          params[:billing_entity_id] = billing_entity.id
          params[:billing_entity_code] = other_entity.code

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.billing_entity_id).to eq(billing_entity.id)
        end
      end
    end

    describe "billing entity binding on downgrade" do
      let(:current_entity) { create(:billing_entity, organization:, code: "entity-x") }
      let(:target_entity) { create(:billing_entity, organization:, code: "entity-y") }
      let(:old_plan) { create(:plan, amount_cents: 100, organization:) }
      let(:plan) { create(:plan, amount_cents: 50, organization:) }

      let(:subscription) do
        create(
          :subscription,
          customer:,
          plan: old_plan,
          status: :active,
          subscription_at: Time.current,
          started_at: Time.current,
          external_id:,
          billing_entity: current_entity
        )
      end

      before { CurrentContext.source = "api" }

      context "when multi_entity_billing flag is OFF" do
        before { subscription.mark_as_active! }

        it "carries over current_subscription.billing_entity_id to the pending subscription" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.next_subscription.billing_entity_id).to eq(current_entity.id)
        end

        it "carries over NULL when current_subscription is not bound to any entity" do
          subscription.update!(billing_entity_id: nil)

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.next_subscription.billing_entity_id).to be_nil
        end

        it "ignores billing_entity_code param and still carries over from current_subscription" do
          params[:billing_entity_code] = target_entity.code

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.next_subscription.billing_entity_id).to eq(current_entity.id)
        end
      end

      context "when multi_entity_billing flag is ON" do
        before do
          subscription.mark_as_active!
          organization.enable_feature_flag!(:multi_entity_billing)
        end

        it "carries over current_subscription.billing_entity_id when no param is provided" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.next_subscription.billing_entity_id).to eq(current_entity.id)
        end

        it "persists NULL when current_subscription is not bound and no param is provided" do
          subscription.update!(billing_entity_id: nil)

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.next_subscription.billing_entity_id).to be_nil
        end

        it "binds the pending subscription to the entity matched by billing_entity_code" do
          params[:billing_entity_code] = target_entity.code

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.next_subscription.billing_entity_id).to eq(target_entity.id)
        end

        it "leaves the current subscription bound to its original entity when the param overrides it" do
          params[:billing_entity_code] = target_entity.code

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.reload.billing_entity_id).to eq(current_entity.id)
        end

        it "binds the pending subscription to the entity matched by billing_entity_id" do
          params[:billing_entity_id] = target_entity.id

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.next_subscription.billing_entity_id).to eq(target_entity.id)
        end

        it "fails with billing_entity_not_found when billing_entity_code is unknown" do
          params[:billing_entity_code] = "unknown-entity-code"

          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("billing_entity_not_found")
        end

        it "fails with billing_entity_not_found when billing_entity_id is unknown" do
          params[:billing_entity_id] = SecureRandom.uuid

          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.error_code).to eq("billing_entity_not_found")
        end
      end

      context "when re-downgrading a starting_in_the_future subscription" do
        let(:subscription) do
          create(
            :subscription,
            customer:,
            plan: old_plan,
            status: :pending,
            subscription_at: 1.day.from_now,
            external_id:,
            billing_entity: current_entity
          )
        end

        before do
          subscription
          organization.enable_feature_flag!(:multi_entity_billing)
        end

        it "re-binds the pending subscription when billing_entity_code is provided" do
          params[:billing_entity_code] = target_entity.code

          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.id).to eq(subscription.id)
          expect(result.subscription.reload.billing_entity_id).to eq(target_entity.id)
        end

        it "leaves the pending subscription's billing entity untouched when no param is provided" do
          result = create_service.call

          expect(result).to be_success
          expect(result.subscription.id).to eq(subscription.id)
          expect(result.subscription.reload.billing_entity_id).to eq(current_entity.id)
        end
      end
    end
  end
end
