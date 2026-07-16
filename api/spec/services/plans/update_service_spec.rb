# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plans::UpdateService do
  subject(:plans_service) { described_class.new(plan:, params: update_args) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:plan_name) { "Updated plan name" }
  let(:plan_invoice_display_name) { "Updated plan invoice display name" }
  let(:sum_billable_metric) { create(:sum_billable_metric, organization:, recurring: true) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:tax1) { create(:tax, organization:) }
  let(:applied_tax) { create(:plan_applied_tax, plan:, tax: tax1) }
  let(:tax2) { create(:tax, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:fixed_charges_args) do
    [
      {
        add_on_id: add_on.id,
        charge_model: "standard",
        invoice_display_name: "fixed_charge1",
        units: 2,
        properties: {amount: "150"},
        tax_codes: [tax1.code]
      },
      {
        add_on_id: add_on.id,
        charge_model: "graduated",
        invoice_display_name: "fixed_charge2",
        units: 1,
        properties: {
          graduated_ranges: [
            {
              from_value: 0,
              to_value: 10,
              per_unit_amount: "2",
              flat_amount: "0"
            },
            {
              from_value: 11,
              to_value: nil,
              per_unit_amount: "3",
              flat_amount: "3"
            }
          ]
        }
      }
    ]
  end

  let(:update_args) do
    {
      name: plan_name,
      invoice_display_name: plan_invoice_display_name,
      code: "new_plan",
      interval: "monthly",
      pay_in_advance: false,
      amount_cents: 200,
      amount_currency: "EUR",
      tax_codes: [tax2.code],
      charges: charges_args,
      fixed_charges: fixed_charges_args
    }
  end

  let(:minimum_commitment_args) do
    {
      amount_cents: minimum_commitment_amount_cents,
      invoice_display_name: minimum_commitment_invoice_display_name,
      tax_codes: [tax1.code]
    }
  end

  let(:minimum_commitment_invoice_display_name) { "Minimum spending" }
  let(:minimum_commitment_amount_cents) { 100 }

  let(:charges_args) do
    [
      {
        billable_metric_id: sum_billable_metric.id,
        charge_model: "standard",
        invoice_display_name: "charge1",
        min_amount_cents: 100,
        tax_codes: [tax1.code]
      },
      {
        billable_metric_id: billable_metric.id,
        charge_model: "graduated",
        invoice_display_name: "charge2",
        properties: {
          graduated_ranges: [
            {
              from_value: 0,
              to_value: 10,
              per_unit_amount: "2",
              flat_amount: "0"
            },
            {
              from_value: 11,
              to_value: nil,
              per_unit_amount: "3",
              flat_amount: "3"
            }
          ]
        }
      }
    ]
  end

  let(:usage_thresholds_args) do
    [
      {
        id: threshold1.id,
        threshold_display_name: "Threshold 1",
        amount_cents: 1_000
      },
      {
        id: threshold2.id,
        threshold_display_name: "Threshold 2",
        amount_cents: 10_000
      },
      {
        id: threshold3.id,
        threshold_display_name: "Threshold 3",
        amount_cents: 100,
        recurring: true
      }
    ]
  end

  let(:threshold1) do
    create(:usage_threshold, plan:, threshold_display_name: "Threshold 1", amount_cents: 1)
  end

  let(:threshold2) do
    create(:usage_threshold, plan:, threshold_display_name: "Threshold 2", amount_cents: 2)
  end

  let(:threshold3) do
    create(:usage_threshold, :recurring, plan:, threshold_display_name: "Threshold 3", amount_cents: 1)
  end

  let(:threshold5) do
    create(:usage_threshold, plan:, threshold_display_name: "Threshold 5", amount_cents: 123)
  end

  describe "call" do
    before do
      applied_tax
    end

    it "updates a plan" do
      result = plans_service.call

      updated_plan = result.plan

      expect(SendWebhookJob).to have_been_enqueued.with("plan.updated", updated_plan)

      expect(updated_plan.name).to eq("Updated plan name")
      expect(updated_plan.invoice_display_name).to eq(plan_invoice_display_name)
      expect(updated_plan.taxes.pluck(:code)).to eq([tax2.code])
      expect(plan.charges.count).to eq(2)
      expect(plan.charges.order(created_at: :asc).first.invoice_display_name).to eq("charge1")
      expect(plan.charges.order(created_at: :asc).second.invoice_display_name).to eq("charge2")
      expect(plan.fixed_charges.count).to eq(2)
      expect(plan.fixed_charges.order(created_at: :asc).first.invoice_display_name).to eq("fixed_charge1")
      expect(plan.fixed_charges.order(created_at: :asc).second.invoice_display_name).to eq("fixed_charge2")
    end

    context "when send_webhook is false" do
      it "does not enqueue the plan.updated webhook but still produces the activity log" do
        described_class.call(plan:, params: update_args, send_webhook: false)

        expect(SendWebhookJob).not_to have_been_enqueued.with("plan.updated", plan)
        expect(Utils::ActivityLog).to have_produced("plan.updated").after_commit.with(plan)
      end
    end

    it "marks invoices as ready to be refreshed" do
      subscription = create(:subscription, organization:, plan:)
      invoice = create(:invoice, :draft)
      create(:invoice_subscription, invoice:, subscription:)

      expect { plans_service.call }.to change { invoice.reload.ready_to_be_refreshed }.to(true)
    end

    context "with activity logs" do
      context "when no parent" do
        it "produces" do
          described_class.call(plan:, params: update_args)

          expect(Utils::ActivityLog).to have_produced("plan.updated").after_commit.with(plan)
        end
      end

      context "when plan is a children" do
        let(:parent_id) { plan.id }
        let(:child_plan) { create(:plan, organization:, parent_id:) }

        it "does not produce" do
          described_class.call(plan: child_plan, params: update_args)

          expect(Utils::ActivityLog).not_to have_received(:produce)
        end
      end
    end

    context "with cascade option" do
      let(:child_plan) { create(:plan, organization:, parent_id:) }
      let(:parent_id) { plan.id }

      before do
        child_plan
        update_args[:cascade_updates] = true
      end

      context "when cascade is true and there is no children plans" do
        let(:parent_id) { nil }

        it "does not enqueue the job for updating subscription fee" do
          expect do
            plans_service.call
          end.not_to have_enqueued_job(Plans::UpdateAmountJob)
        end
      end

      context "when cascade is true and child plan is already updated" do
        let(:child_plan) { create(:plan, organization:, parent_id:, amount_cents: 150) }

        it "does not enqueue the job for updating subscription fee" do
          expect do
            plans_service.call
          end.not_to have_enqueued_job(Plans::UpdateAmountJob)
        end
      end

      context "when cascade is true with children plans not touched" do
        it "enqueues the job for updating subscription fee" do
          expect do
            plans_service.call
          end.to have_enqueued_job(Plans::UpdateAmountJob)
        end
      end

      context "when cascade is false with children plans not touched" do
        before do
          update_args[:cascade_updates] = false
        end

        it "does not enqueue the job for updating subscription fee" do
          expect do
            plans_service.call
          end.not_to have_enqueued_job(Plans::UpdateAmountJob)
        end
      end

      context "when an in-transaction failure follows a charge update" do
        let(:existing_charge) { create(:standard_charge, plan:, billable_metric:) }
        let(:update_args) do
          {
            charges: [
              {
                id: existing_charge.id,
                billable_metric_id: billable_metric.id,
                charge_model: "standard",
                properties: {amount: "0"}
              },
              {
                billable_metric_id: billable_metric.id,
                charge_model: "standard"
              }
            ]
          }
        end

        before do
          existing_charge
          allow(Charges::CreateService).to receive(:call!).and_raise(
            ActiveRecord::RecordInvalid.new(Charge.new.tap { |c| c.errors.add(:base, "boom") })
          )
        end

        it "does not enqueue Charges::UpdateChildrenJob" do
          expect { plans_service.call }.not_to have_enqueued_job(Charges::UpdateChildrenJob)
        end
      end
    end

    context "when thresholds are present" do
      let(:usage_thresholds) do
        updated_plan.usage_thresholds.order(threshold_display_name: :asc)
      end

      let(:updated_plan) { plans_service.call.plan }

      before do
        threshold1
        threshold2
        threshold3
        threshold5
      end

      context "with premium license", :premium do
        context "when progressive billing premium integration is present" do
          before do
            plan.organization.update!(premium_integrations: ["progressive_billing"])
          end

          context "when thresholds args are passed" do
            before do
              update_args[:usage_thresholds] = usage_thresholds_args

              update_args[:usage_thresholds] << {
                threshold_display_name: "Threshold 4",
                amount_cents: 4_000
              }
            end

            it "updates the existing thresholds" do
              expect(usage_thresholds.first).to have_attributes(amount_cents: 1_000)
              expect(usage_thresholds.second).to have_attributes(amount_cents: 10_000)
              expect(usage_thresholds.third).to have_attributes(amount_cents: 100)
              expect(usage_thresholds.fourth).to have_attributes(amount_cents: 4_000)
            end

            it "creates new thresholds and deletes thresholds that are not in the args" do
              expect(plan.usage_thresholds.count).to eq(4)
              expect(plan.usage_thresholds.order(threshold_display_name: :asc).last.amount_cents).to eq(123)
              expect(usage_thresholds.count).to eq(4)
              expect(usage_thresholds.fourth).to have_attributes(amount_cents: 4_000)
            end
          end

          context "when thresholds args are passed as empty array" do
            before do
              update_args[:usage_thresholds] = []
            end

            it "deletes all existing thresholds" do
              expect(usage_thresholds.count).to eq(0)
            end
          end

          context "when thresholds args are not passed" do
            it "does not update the thresholds" do
              expect(usage_thresholds.count).to eq(4)
              expect(usage_thresholds.fourth).to have_attributes(
                threshold_display_name: "Threshold 5"
              )
            end
          end
        end
      end
    end

    context "when thresholds are not present" do
      let(:usage_thresholds) do
        updated_plan.usage_thresholds.order(threshold_display_name: :asc)
      end

      let(:updated_plan) { plans_service.call.plan }

      context "without premium license" do
        it "does not create progressive billing thresholds" do
          expect(usage_thresholds.count).to eq(0)
        end
      end

      context "with premium license", :premium do
        context "when progressive billing premium integration is not present" do
          it "does not create progressive billing thresholds" do
            expect(usage_thresholds.count).to eq(0)
          end
        end

        context "when progressive billing premium integration is present" do
          before do
            plan.organization.update!(premium_integrations: ["progressive_billing"])
          end

          context "when thresholds args are passed" do
            before do
              update_args[:usage_thresholds] = usage_thresholds_args
            end

            it "creates new thresholds" do
              expect(usage_thresholds.count).to eq(3)
              expect(usage_thresholds.first).to have_attributes(
                amount_cents: 1_000
              )
              expect(usage_thresholds.second).to have_attributes(
                amount_cents: 10_000
              )
              expect(usage_thresholds.third).to have_attributes(
                amount_cents: 100
              )
            end
          end
        end
      end
    end

    context "when charges are not passed" do
      let(:charge) { create(:standard_charge, plan:) }
      let(:update_args) do
        {
          name: plan_name,
          code: "new_plan",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 200,
          amount_currency: "EUR"
        }
      end

      before { charge }

      it "does not sanitize charges" do
        result = plans_service.call

        updated_plan = result.plan
        expect(updated_plan.name).to eq("Updated plan name")
        expect(plan.charges.count).to eq(1)
      end
    end

    context "when plan amount is updated" do
      let(:new_customer) { create(:customer, organization:) }
      let(:subscription) { create(:subscription, plan:, customer: new_customer) }
      let(:update_args) do
        {
          name: plan_name,
          code: "new_plan",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 5,
          amount_currency: "EUR"
        }
      end

      before { subscription }

      it "correctly updates plan" do
        result = plans_service.call

        updated_plan = result.plan
        expect(updated_plan.name).to eq("Updated plan name")
        expect(updated_plan.amount_cents).to eq(5)
      end

      context "when there are pending subscriptions which are not relevant after the amount cents decrease" do
        let(:pending_plan) { create(:plan, organization:, amount_cents: 10) }
        let(:pending_subscription) do
          create(:subscription, plan: pending_plan, status: :pending, previous_subscription_id: subscription.id)
        end

        before { pending_subscription }

        it "correctly cancels pending subscriptions" do
          result = plans_service.call

          updated_plan = result.plan
          expect(updated_plan.name).to eq("Updated plan name")
          expect(updated_plan.amount_cents).to eq(5)
          expect(Subscription.find_by(id: pending_subscription.id).status).to eq("canceled")
        end
      end

      context "when there are pending subscriptions which are not relevant after the amount cents increase" do
        let(:original_plan) { create(:plan, organization:, amount_cents: 150) }
        let(:subscription) { create(:subscription, plan: original_plan, customer: new_customer) }
        let(:pending_subscription) do
          create(:subscription, plan:, status: :pending, previous_subscription_id: subscription.id)
        end
        let(:update_args) do
          {
            name: plan_name,
            code: "new_plan",
            interval: "monthly",
            pay_in_advance: false,
            amount_cents: 200,
            amount_currency: "EUR"
          }
        end
        let(:plan_upgrade_result) { BaseService::Result.new }

        before do
          allow(Subscriptions::PlanUpgradeService)
            .to receive(:call)
            .and_return(plan_upgrade_result)

          pending_subscription
        end

        it "upgrades subscription plan" do
          plans_service.call

          expect(Subscriptions::PlanUpgradeService).to have_received(:call).with(
            current_subscription: subscription,
            plan: plan,
            params: {name: pending_subscription.name}
          )
        end

        it "updates the plan" do
          result = plans_service.call

          expect(result.plan.name).to eq("Updated plan name")
          expect(result.plan.amount_cents).to eq(200)
        end

        context "when the pending subscription has activation rules" do
          before do
            create(:subscription_activation_rule, subscription: pending_subscription, organization:, timeout_hours: 24)
          end

          it "forwards the activation_rules to the plan upgrade" do
            plans_service.call

            expect(Subscriptions::PlanUpgradeService).to have_received(:call).with(
              current_subscription: subscription,
              plan: plan,
              params: {
                name: pending_subscription.name,
                activation_rules: [{type: "payment", timeout_hours: 24}]
              }
            )
          end
        end

        context "when pending subscription does not have a previous one" do
          let(:pending_subscription) do
            create(:subscription, plan:, status: :pending, previous_subscription_id: nil)
          end

          it "does not upgrade it" do
            plans_service.call

            expect(Subscriptions::PlanUpgradeService).not_to have_received(:call)
          end
        end

        context "when subscription upgrade fails" do
          let(:plan_upgrade_result) do
            BaseService::Result.new.validation_failure!(
              errors: {billing_time: ["value_is_invalid"]}
            )
          end

          it "returns an error" do
            result = plans_service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages).to eq({billing_time: ["value_is_invalid"]})
          end
        end
      end
    end

    context "when pending-promotion preserves billing entity from previous subscription" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:original_plan) { create(:plan, organization:, amount_cents: 150) }
      let(:new_customer) { create(:customer, organization:) }
      let(:original_active_sub) do
        create(
          :subscription,
          plan: original_plan,
          customer: new_customer,
          status: :active,
          billing_entity:,
          subscription_at: Time.current,
          started_at: Time.current
        )
      end
      let(:pending_subscription) do
        create(:subscription, plan:, status: :pending, previous_subscription_id: original_active_sub.id, customer: new_customer)
      end
      let(:update_args) do
        {
          name: plan_name,
          code: "new_plan",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 200,
          amount_currency: "EUR"
        }
      end

      before do
        original_active_sub
        pending_subscription
      end

      it "carries the previous subscription's billing_entity onto the new active subscription" do
        plans_service.call

        new_active_sub = Subscription.where(previous_subscription_id: original_active_sub.id, status: :active).first
        expect(new_active_sub).to be_present
        expect(new_active_sub.billing_entity_id).to eq(billing_entity.id)
      end
    end

    context "when plan is not found" do
      let(:applied_tax) { nil }
      let(:plan) { nil }

      it "returns an error" do
        result = plans_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("plan_not_found")
      end
    end

    context "with validation error" do
      let(:plan_name) { nil }

      it "returns an error" do
        result = plans_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:name]).to eq(["value_is_mandatory"])
      end

      context "with new charge" do
        let(:plan_name) { "foo" }

        let(:charges_args) do
          [
            {
              billable_metric_id: sum_billable_metric.id,
              charge_model: "standard",
              pay_in_advance: false,
              invoiceable: true,
              properties: {
                amount: "100"
              }
            }
          ]
        end

        it "updates the plan" do
          result = plans_service.call
          expect(result.plan.charges.count).to eq(1)
        end

        it "auto-generates charge code when not provided" do
          result = plans_service.call
          expect(result.plan.charges.first.code).to eq(sum_billable_metric.code)
        end
      end

      context "with premium charge model" do
        let(:plan_name) { "foo" }

        let(:charges_args) do
          [
            {
              billable_metric_id: sum_billable_metric.id,
              charge_model: "graduated_percentage",
              pay_in_advance: true,
              invoiceable: false,
              properties: {
                graduated_percentage_ranges: [
                  {
                    from_value: 0,
                    to_value: 10,
                    rate: "3",
                    flat_amount: "0"
                  },
                  {
                    from_value: 11,
                    to_value: nil,
                    rate: "2",
                    flat_amount: "3"
                  }
                ]
              }
            }
          ]
        end

        it "returns an error" do
          result = plans_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:charge_model]).to eq(["graduated_percentage_requires_premium_license"])
        end

        context "when premium", :premium do
          it "saves premium charge model" do
            plans_service.call

            expect(plan.charges.graduated_percentage.first).to have_attributes(
              {
                pay_in_advance: true,
                invoiceable: false,
                charge_model: "graduated_percentage"
              }
            )
          end
        end
      end
    end

    context "with metrics from other organization" do
      let(:billable_metric) { create(:billable_metric) }

      it "returns an error" do
        result = plans_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("billable_metrics_not_found")
      end
    end

    context "when plan has no minimum commitment" do
      context "when minimum commitment arguments are present" do
        before { update_args.merge!({minimum_commitment: minimum_commitment_args}) }

        context "when license is premium", :premium do
          it "creates minimum commitment" do
            result = plans_service.call
            commitment = result.plan.minimum_commitment

            expect(commitment.amount_cents).to eq(minimum_commitment_args[:amount_cents])
            expect(commitment.invoice_display_name).to eq(minimum_commitment_args[:invoice_display_name])
          end
        end

        context "when license is not premium" do
          it "does not create minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment).to be_nil
          end
        end
      end

      context "when minimum commitment arguments are not present" do
        context "when license is premium", :premium do
          it "does not create minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment).to be_nil
          end
        end

        context "when license is not premium" do
          it "does not create minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment).to be_nil
          end
        end
      end

      context "when minimum commitment arguments is an empty hash" do
        before { update_args.merge!({minimum_commitment: {}}) }

        context "when license is premium", :premium do
          it "does not create minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment).to be_nil
          end
        end

        context "when license is not premium" do
          it "does not create minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment).to be_nil
          end
        end
      end
    end

    context "when plan has minimum commitment" do
      let(:minimum_commitment) { create(:commitment, plan:) }

      before { minimum_commitment }

      context "when minimum commitment arguments are present" do
        before { update_args.merge!({minimum_commitment: minimum_commitment_args}) }

        context "when license is premium", :premium do
          it "updates minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment.amount_cents).to eq(minimum_commitment_args[:amount_cents])
          end
        end

        context "when license is not premium" do
          it "does not update minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment.amount_cents).not_to eq(update_args[:amount_cents])
          end
        end
      end

      context "when only some minimum commitment arguments are present" do
        let(:minimum_commitment_args) do
          {invoice_display_name: minimum_commitment_invoice_display_name}
        end

        before { update_args.merge!({minimum_commitment: minimum_commitment_args}) }

        context "when license is premium", :premium do
          it "does not update minimum commitment args that are not present" do
            result = plans_service.call

            expect(result.plan.minimum_commitment.invoice_display_name).to eq(minimum_commitment_invoice_display_name)
            expect(result.plan.minimum_commitment.amount_cents).to eq(minimum_commitment.amount_cents)
          end
        end

        context "when license is not premium" do
          it "does not update minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment.invoice_display_name).to eq(minimum_commitment.invoice_display_name)
            expect(result.plan.minimum_commitment.amount_cents).to eq(minimum_commitment.amount_cents)
          end
        end
      end

      context "when minimum commitment arguments are not present" do
        context "when license is premium", :premium do
          it "does not update minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment.amount_cents).not_to eq(update_args[:amount_cents])
          end
        end

        context "when license is not premium" do
          it "does not update minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment.amount_cents).not_to eq(update_args[:amount_cents])
          end
        end
      end

      context "when minimum commitment arguments is an empty hash" do
        before { update_args.merge!({minimum_commitment: {}}) }

        context "when license is premium", :premium do
          it "deletes plan minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment).to be_nil
          end
        end

        context "when license is not premium" do
          it "does not delete minimum commitment" do
            result = plans_service.call

            expect(result.plan.minimum_commitment).not_to be_nil
          end
        end
      end
    end

    context "with existing charges" do
      let!(:existing_charge) do
        create(
          :standard_charge,
          plan_id: plan.id,
          billable_metric_id: sum_billable_metric.id,
          amount_currency: "USD",
          properties: {
            amount: "300"
          }
        )
      end

      let(:billable_metric_filter) do
        create(
          :billable_metric_filter,
          billable_metric: sum_billable_metric,
          key: "payment_method",
          values: %w[card physical]
        )
      end

      let(:update_args) do
        {
          id: plan.id,
          name: plan_name,
          code: "new_plan",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 200,
          amount_currency: "EUR",
          charges: [
            {
              id: existing_charge.id,
              billable_metric_id: sum_billable_metric.id,
              charge_model: "standard",
              pay_in_advance: true,
              prorated: true,
              invoiceable: false,
              filters: [
                {
                  invoice_display_name: "Card filter",
                  properties: {amount: "90"},
                  values: {billable_metric_filter.key => ["card"]}
                }
              ]
            },
            {
              billable_metric_id: billable_metric.id,
              charge_model: "standard",
              min_amount_cents: 100,
              properties: {
                amount: "300"
              },
              tax_codes: [tax1.code]
            }
          ]
        }
      end

      it "updates existing charge and creates an other one" do
        expect { plans_service.call }.to change(Charge, :count).by(1)

        charge = plan.charges.where(pay_in_advance: false).first
        expect(charge.taxes.pluck(:code)).to eq([tax1.code])
      end

      it "updates existing charge" do
        plans_service.call

        expect(existing_charge.reload).to have_attributes(
          prorated: true,
          properties: {"amount" => "0"}
        )

        expect(existing_charge.filters.first).to have_attributes(
          invoice_display_name: "Card filter",
          properties: {"amount" => "90"}
        )
        expect(existing_charge.filters.first.values.first).to have_attributes(
          billable_metric_filter_id: billable_metric_filter.id,
          values: ["card"]
        )
      end

      it "does not update premium attributes" do
        plan = plans_service.call.plan

        expect(existing_charge.reload).to have_attributes(pay_in_advance: true, invoiceable: true)
        expect(plan.charges.where(pay_in_advance: false).first.min_amount_cents).to eq(0)
      end

      context "when premium", :premium do
        it "saves premium attributes" do
          plans_service.call

          expect(existing_charge.reload).to have_attributes(pay_in_advance: true, invoiceable: false)
          charge = plan.charges.where(pay_in_advance: false).first
          expect(charge.min_amount_cents).to eq(100)
        end
      end

      context "with cascade option and update charge case" do
        let(:child_plan) { create(:plan, organization:, parent_id:) }
        let(:parent_id) { plan.id }
        let(:charge_parent_id) { existing_charge.id }
        let(:child_charge) do
          create(
            :standard_charge,
            plan_id: child_plan.id,
            parent_id: charge_parent_id,
            billable_metric_id: sum_billable_metric.id,
            properties: {amount: "300"}
          )
        end

        before do
          child_charge
          update_args[:cascade_updates] = true
        end

        context "when cascade is true and there is no children plans" do
          let(:parent_id) { nil }

          it "does not enqueue the job for updating charge" do
            expect do
              plans_service.call
            end.not_to have_enqueued_job(Charges::UpdateChildrenJob)
          end
        end

        context "when cascade is true and there are children plans" do
          it "enqueues the job for updating charge" do
            expect do
              plans_service.call
            end.to have_enqueued_job(Charges::UpdateChildrenJob)
          end
        end

        context "when cascade is false with children plans" do
          before do
            update_args[:cascade_updates] = false
          end

          it "does not enqueue the job for updating charge" do
            expect do
              plans_service.call
            end.not_to have_enqueued_job(Charges::DestroyChildrenJob)
          end
        end
      end

      context "with cascade option and create charge case" do
        let(:child_plan) { create(:plan, organization:, parent_id:) }
        let(:parent_id) { plan.id }

        before do
          child_plan
          update_args[:cascade_updates] = true
        end

        context "when cascade is true and there is no children plans" do
          let(:parent_id) { nil }

          it "does not enqueue the job for creating new charge" do
            expect do
              plans_service.call
            end.not_to have_enqueued_job(Charges::CreateChildrenJob)
          end
        end

        context "when cascade is true and there are children plans" do
          it "enqueues the job for creating new charge" do
            expect do
              plans_service.call
            end.to have_enqueued_job(Charges::CreateChildrenJob)
              .with(charge: Charge, payload: Hash)
          end
        end

        context "when cascade is false with children plans" do
          before do
            update_args[:cascade_updates] = false
          end

          it "does not enqueue the job for creating new charge" do
            expect do
              plans_service.call
            end.not_to have_enqueued_job(Charges::CreateChildrenJob)
          end
        end
      end
    end

    context "with existing charge attached to subscription" do
      let(:existing_charge) do
        create(
          :standard_charge,
          plan_id: plan.id,
          billable_metric_id: sum_billable_metric.id,
          amount_currency: "USD",
          properties: {
            amount: "300"
          }
        )
      end

      let(:subscription) { create(:subscription, plan:) }

      let(:update_args) do
        {
          id: plan.id,
          code: "new_plan",
          amount_cents: 200,
          charges: [
            {
              id: existing_charge.id,
              billable_metric_id: sum_billable_metric.id,
              charge_model: "standard",
              tax_codes: [tax2.code]
            }
          ]
        }
      end

      before do
        existing_charge && subscription
      end

      it "updates existing charge" do
        expect { plans_service.call }.not_to change(Charge, :count)
        expect(plan.charges.first.taxes.pluck(:code)).to eq([tax2.code])
      end
    end

    context "with charge to delete" do
      let(:subscription) { create(:subscription, plan:) }
      let(:charge) do
        create(
          :standard_charge,
          plan_id: plan.id,
          billable_metric_id: billable_metric.id,
          properties: {amount: "300"}
        )
      end

      let(:update_args) do
        {
          id: plan.id,
          name: plan_name,
          code: "new_plan",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 200,
          amount_currency: "EUR",
          charges: []
        }
      end

      let(:billable_metric) { sum_billable_metric }

      before do
        subscription
        charge
      end

      it "discards the charge" do
        freeze_time do
          expect { plans_service.call }
            .to change { charge.reload.deleted_at }.from(nil).to(Time.current)
        end
      end

      context "with cascade option" do
        let(:child_plan) { create(:plan, organization:, parent_id:) }
        let(:parent_id) { plan.id }
        let(:charge_parent_id) { charge.id }
        let(:child_charge) do
          create(
            :standard_charge,
            plan_id: child_plan.id,
            parent_id: charge_parent_id,
            billable_metric_id: billable_metric.id,
            properties: {amount: "300"}
          )
        end

        before do
          child_charge
          update_args[:cascade_updates] = true
        end

        context "when cascade is true and there is no children plans" do
          let(:parent_id) { nil }

          it "does not enqueue the job for removing charge" do
            expect do
              plans_service.call
            end.not_to have_enqueued_job(Charges::DestroyChildrenJob)
          end
        end

        context "when cascade is true and there are children plans" do
          it "enqueues the job for removing charge" do
            expect do
              plans_service.call
            end.to have_enqueued_job(Charges::DestroyChildrenJob)
          end
        end

        context "when cascade is false with children plans" do
          before do
            update_args[:cascade_updates] = false
          end

          it "does not enqueue the job for removing charge" do
            expect do
              plans_service.call
            end.not_to have_enqueued_job(Charges::DestroyChildrenJob)
          end
        end
      end
    end

    context "when attached to a subscription" do
      let(:existing_charge) do
        create(
          :standard_charge,
          plan_id: plan.id,
          billable_metric_id: sum_billable_metric.id,
          properties: {
            amount: "300"
          }
        )
      end

      let(:update_args) do
        {
          id: plan.id,
          name: plan_name,
          code: "new_plan",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 200,
          amount_currency: "EUR",
          charges: [
            {
              id: existing_charge.id,
              billable_metric_id: sum_billable_metric.id,
              charge_model: "standard",
              properties: {
                amount: "100"
              }
            },
            {
              billable_metric_id: billable_metric.id,
              charge_model: "standard",
              properties: {
                amount: "300"
              }
            }
          ]
        }
      end

      before do
        create(:subscription, plan:)
      end

      it "updates only name description and new charges" do
        result = plans_service.call
        updated_plan = result.plan

        expect(updated_plan.name).to eq("Updated plan name")
        expect(plan.charges.count).to eq(2)
      end
    end

    context "with bill_charges_monthly functionality" do
      context "when interval is yearly and bill_fixed_charges_monthly is sent" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "yearly",
            bill_charges_monthly: true
          }
        end

        it "updates bill_charges_monthly" do
          result = plans_service.call

          expect(result.plan.bill_charges_monthly).to eq(true)
        end
      end

      context "when interval is yearly and bill_charges_monthly is not provided" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "yearly"
          }
        end

        it "sets bill_charges_monthly to false" do
          result = plans_service.call

          expect(result.plan.bill_charges_monthly).to eq(false)
        end
      end

      context "when interval is semiannual and bill_charges_monthly is sent" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "semiannual",
            bill_charges_monthly: true
          }
        end

        it "updates bill_charges_monthly" do
          result = plans_service.call

          expect(result.plan.bill_charges_monthly).to eq(true)
        end
      end

      context "when interval is semiannual and bill_charges_monthly is not provided" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "semiannual"
          }
        end

        it "sets bill_charges_monthly to false" do
          result = plans_service.call

          expect(result.plan.bill_charges_monthly).to eq(false)
        end
      end

      context "when interval is not yearly or semiannual" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "monthly",
            bill_charges_monthly: true
          }
        end

        it "does not set bill_charges_monthly" do
          result = plans_service.call

          expect(result.plan.bill_charges_monthly).to be_nil
        end
      end
    end

    context "with bill_fixed_charges_monthly functionality" do
      context "when interval is yearly and bill_fixed_charges_monthly is sent" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "yearly",
            bill_fixed_charges_monthly: true
          }
        end

        it "updates bill_fixed_charges_monthly" do
          result = plans_service.call

          expect(result.plan.bill_fixed_charges_monthly).to eq(true)
        end
      end

      context "when interval is yearly and bill_fixed_charges_monthly is not provided" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "yearly"
          }
        end

        it "sets bill_fixed_charges_monthly to false" do
          result = plans_service.call

          expect(result.plan.bill_fixed_charges_monthly).to eq(false)
        end
      end

      context "when interval is semiannual and bill_fixed_charges_monthly is sent" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "semiannual",
            bill_fixed_charges_monthly: true
          }
        end

        it "updates bill_fixed_charges_monthly" do
          result = plans_service.call

          expect(result.plan.bill_fixed_charges_monthly).to eq(true)
        end
      end

      context "when interval is semiannual and bill_fixed_charges_monthly is not provided" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "semiannual"
          }
        end

        it "sets bill_fixed_charges_monthly to false" do
          result = plans_service.call

          expect(result.plan.bill_fixed_charges_monthly).to eq(false)
        end
      end

      context "when interval is not yearly or semiannual" do
        let(:update_args) do
          {
            name: plan_name,
            interval: "monthly",
            bill_fixed_charges_monthly: true
          }
        end

        it "does not set bill_fixed_charges_monthly" do
          result = plans_service.call

          expect(result.plan.bill_fixed_charges_monthly).to be_nil
        end
      end
    end

    context "with fixed_charges validation" do
      context "when fixed_charges are valid" do
        let(:update_args) do
          {
            name: plan_name,
            fixed_charges: fixed_charges_args
          }
        end

        it "validates fixed_charges successfully" do
          result = plans_service.call

          expect(result).to be_success
        end
      end

      context "when fixed_charges add_on is not found" do
        let(:update_args) do
          {
            name: plan_name,
            fixed_charges: [
              {
                add_on_id: add_on.code,
                charge_model: "standard",
                units: 1,
                properties: {amount: "100"}
              }
            ]
          }
        end

        it "returns validation error" do
          result = plans_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("add_ons_not_found")
        end
      end

      context "when no fixed_charges are provided" do
        let(:update_args) do
          {
            name: plan_name
          }
        end

        it "does not validate fixed_charges" do
          result = plans_service.call

          expect(result).to be_success
        end
      end

      context "when both charges and fixed_charges are provided" do
        let(:update_args) do
          {
            name: plan_name,
            charges: charges_args,
            fixed_charges: fixed_charges_args
          }
        end

        it "validates both successfully" do
          result = plans_service.call

          expect(result).to be_success
        end
      end
    end

    context "with fixed_charges flow" do
      let(:update_args) do
        {
          name: plan_name,
          interval: "yearly",
          bill_fixed_charges_monthly: true,
          fixed_charges: fixed_charges_args
        }
      end

      context "when plan has no fixed_charges" do
        before do
          allow(FixedCharges::CreateService).to receive(:call!).and_call_original
        end

        it "handles adding fixed_charges flow successfully" do
          result = plans_service.call

          expect(result).to be_success
          expect(result.plan.bill_fixed_charges_monthly).to eq(true)
          expect(result.plan.fixed_charges.count).to eq(2)
          expect(result.plan.fixed_charges.map(&:invoice_display_name)).to match_array(["fixed_charge1", "fixed_charge2"])
        end

        it "auto-generates fixed charge codes when not provided" do
          result = plans_service.call

          expect(result.plan.fixed_charges.pluck(:code)).to match_array([add_on.code, "#{add_on.code}_2"])
        end

        it "calls FixedCharges::CreateService with timestamp" do
          freeze_time do
            plans_service.call

            expect(FixedCharges::CreateService).to have_received(:call!).twice
            expect(FixedCharges::CreateService)
              .to have_received(:call!)
              .with(plan:, params: fixed_charges_args.first.merge(code: add_on.code), timestamp: Time.current.to_i)

            expect(FixedCharges::CreateService)
              .to have_received(:call!)
              .with(plan:, params: fixed_charges_args.second.merge(code: "#{add_on.code}_2"), timestamp: Time.current.to_i)
          end
        end

        context "with plan having active subscriptions" do
          let(:subscription) { create(:subscription, :active, plan:) }

          before { subscription }

          it "does not enqueue a Invoices::CreateAllPayInAdvanceFixedChargesJob" do
            expect { plans_service.call }
              .not_to have_enqueued_job(Invoices::CreateAllPayInAdvanceFixedChargesJob)
          end
        end

        context "when fixed charge params are pay in advance" do
          let(:fixed_charges_args) do
            [
              {
                add_on_id: add_on.id,
                charge_model: "standard",
                invoice_display_name: "fixed_charge1",
                units: 2,
                pay_in_advance: true,
                properties: {amount: "150"},
                tax_codes: [tax1.code]
              }
            ]
          end

          it "creates fixed charge with pay in advance" do
            result = plans_service.call

            expect(result).to be_success
            expect(result.plan.fixed_charges.count).to eq(1)
            expect(result.plan.fixed_charges.first).to be_pay_in_advance
          end

          context "with plan having active subscriptions" do
            let(:subscription) { create(:subscription, :active, plan:) }

            before { subscription }

            it "enqueues a single Invoices::CreateAllPayInAdvanceFixedChargesJob for the plan" do
              freeze_time do
                expect { plans_service.call }
                  .to have_enqueued_job(Invoices::CreateAllPayInAdvanceFixedChargesJob)
                  .with(plan, Time.current.to_i)
              end
            end

            it "enqueues a Invoices::CreatePayInAdvanceFixedChargesJob for active subscriptions" do
              freeze_time do
                perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) do
                  plans_service.call
                end

                expect(Invoices::CreatePayInAdvanceFixedChargesJob)
                  .to have_been_enqueued
                  .with(subscription, Time.current.to_i)
              end
            end
          end

          context "without active subscriptions" do
            let(:subscription) { create(:subscription, :pending, plan:) }

            before { subscription }

            it "does not enqueue a Invoices::CreatePayInAdvanceFixedChargesJob" do
              perform_enqueued_jobs(only: Invoices::CreateAllPayInAdvanceFixedChargesJob) do
                plans_service.call
              end

              expect(Invoices::CreatePayInAdvanceFixedChargesJob).not_to have_been_enqueued
            end
          end
        end
      end

      context "when plan has fixed_charges" do
        let(:fixed_charge_to_update) { create(:fixed_charge, plan:, invoice_display_name: "fixed_charge_to_update", units: 1, add_on:) }
        let(:fixed_charge_to_delete) { create(:fixed_charge, plan:, invoice_display_name: "fixed_charge_to_delete", units: 2) }
        let(:fixed_charges_args) do
          [
            {
              id: fixed_charge_to_update.id,
              add_on_id: add_on.id,
              charge_model: "standard",
              invoice_display_name: "fixed_charge1",
              units: 2,
              properties: {amount: "150"},
              tax_codes: [tax1.code]
            },
            {
              add_on_id: add_on.id,
              charge_model: "graduated",
              invoice_display_name: "fixed_charge2",
              units: 1,
              properties: {
                graduated_ranges: [
                  {
                    from_value: 0,
                    to_value: 10,
                    per_unit_amount: "2",
                    flat_amount: "0"
                  },
                  {
                    from_value: 11,
                    to_value: nil,
                    per_unit_amount: "3",
                    flat_amount: "3"
                  }
                ]
              }
            }
          ]
        end

        before do
          fixed_charge_to_update
          fixed_charge_to_delete
          update_args[:cascade_updates] = true

          allow(FixedCharges::UpdateService).to receive(:call!).and_call_original
        end

        it "handles update, edit and delete fixed_charges flow successfully" do
          result = plans_service.call

          expect(result).to be_success
          expect(result.plan.fixed_charges.count).to eq(2)
          expect(result.plan.fixed_charges.map(&:id)).to include(fixed_charge_to_update.id)
          expect(result.plan.fixed_charges.map(&:id)).not_to include(fixed_charge_to_delete.id)
        end

        it "calls FixedCharges::UpdateService with timestamp" do
          freeze_time do
            plans_service.call

            expect(FixedCharges::UpdateService).to have_received(:call!).with(
              fixed_charge: fixed_charge_to_update,
              params: {
                id: fixed_charge_to_update.id,
                add_on_id: add_on.id,
                charge_model: "standard",
                invoice_display_name: "fixed_charge1",
                units: 2,
                properties: {amount: "150"},
                tax_codes: [tax1.code]
              },
              timestamp: Time.current.to_i,
              trigger_billing: false
            )
          end
        end

        context "when plan has children" do
          let(:parent_id) { plan.id }
          let(:child_plan) { create(:plan, organization:, parent_id:) }

          before { child_plan }

          it "schedules job to update fixed_charges of children plans" do
            expect do
              plans_service.call
            end.to have_enqueued_job(FixedCharges::CascadePlanUpdateJob).exactly(1).times
          end

          it "schedules job to delete fixed_charges of children plans" do
            expect do
              plans_service.call
            end.to have_enqueued_job(FixedCharges::DestroyChildrenJob).exactly(1).times
          end
        end
      end
    end
  end

  describe "metadata" do
    context "when metadata is provided" do
      let(:update_args) do
        {
          name: plan_name,
          metadata: {key1: "value1", key2: "value2"}
        }
      end

      it "creates metadata" do
        result = plans_service.call

        expect(result).to be_success
        expect(result.plan.metadata.value).to eq("key1" => "value1", "key2" => "value2")
      end
    end

    context "when metadata already exists" do
      before do
        create(:item_metadata, owner: plan, organization:, value: {"existing" => "value", "key1" => "old"})
      end

      context "with partial_metadata: false" do
        subject(:plans_service) { described_class.new(plan:, params: update_args, partial_metadata: false) }

        let(:update_args) do
          {
            name: plan_name,
            metadata: {key1: "value1", key2: "value2"}
          }
        end

        it "replaces all metadata" do
          result = plans_service.call

          expect(result).to be_success
          expect(result.plan.metadata.value).to eq("key1" => "value1", "key2" => "value2")
        end
      end

      context "with partial_metadata: true" do
        subject(:plans_service) { described_class.new(plan:, params: update_args, partial_metadata: true) }

        let(:update_args) do
          {
            name: plan_name,
            metadata: {key1: "value1", key2: "value2"}
          }
        end

        it "merges metadata" do
          result = plans_service.call

          expect(result).to be_success
          expect(result.plan.metadata.value).to eq("existing" => "value", "key1" => "value1", "key2" => "value2")
        end
      end
    end

    context "when metadata is nil" do
      before do
        create(:item_metadata, owner: plan, organization:, value: {"existing" => "value"})
      end

      let(:update_args) do
        {
          name: plan_name,
          metadata: nil
        }
      end

      it "deletes metadata" do
        result = plans_service.call

        expect(result).to be_success
        expect(result.plan.metadata).to be_nil
      end
    end

    context "when metadata is empty hash" do
      before do
        create(:item_metadata, owner: plan, organization:, value: {"existing" => "value"})
      end

      let(:update_args) do
        {
          name: plan_name,
          metadata: {}
        }
      end

      it "replaces metadata with empty hash" do
        result = plans_service.call

        expect(result).to be_success
        expect(result.plan.metadata.value).to eq({})
      end
    end

    context "when metadata is not provided" do
      let(:metadata) { create(:item_metadata, owner: plan, organization:, value: {"existing" => "value"}) }

      let(:update_args) do
        {
          name: plan_name
        }
      end

      before do
        metadata
      end

      it "does not change metadata" do
        result = plans_service.call

        expect(result).to be_success
        expect(result.plan.metadata.value).to eq("existing" => "value")
      end
    end
  end
end
