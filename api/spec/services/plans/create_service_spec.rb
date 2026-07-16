# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plans::CreateService do
  let(:plans_service) { described_class.new(create_args) }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:create_args) do
    {
      name: plan_name,
      invoice_display_name: plan_invoice_display_name,
      organization_id: organization.id,
      code: "new_plan",
      interval:,
      pay_in_advance: false,
      amount_cents: 200,
      amount_currency: "EUR",
      tax_codes: [plan_tax.code],
      charges: charges_args,
      fixed_charges: fixed_charges_args,
      usage_thresholds: usage_thresholds_args,
      minimum_commitment: minimum_commitment_args
    }
  end

  let(:plan_name) { "Some plan name" }
  let(:plan_invoice_display_name) { "Some plan invoice name" }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:sum_billable_metric) { create(:sum_billable_metric, organization:, recurring: true) }
  let(:add_on) { create(:add_on, organization:) }
  let(:plan_tax) { create(:tax, organization:) }
  let(:charge_tax) { create(:tax, organization:) }
  let(:pricing_unit) { create(:pricing_unit, organization:) }
  let(:interval) { "monthly" }

  let(:billable_metric_filter) do
    create(:billable_metric_filter, billable_metric:, key: "payment_method", values: %w[card physical])
  end

  let(:minimum_commitment_args) do
    {
      amount_cents: minimum_commitment_amount_cents,
      invoice_display_name: minimum_commitment_invoice_display_name,
      tax_codes: [plan_tax.code]
    }
  end

  let(:minimum_commitment_invoice_display_name) { "Minimum spending" }
  let(:minimum_commitment_amount_cents) { 100 }

  let(:charges_args) do
    [
      {
        applied_pricing_unit: applied_pricing_unit_args,
        billable_metric_id: billable_metric.id,
        charge_model: "standard",
        min_amount_cents: 100,
        tax_codes: [charge_tax.code],
        filters: [
          {
            values: {billable_metric_filter.key => ["card"]},
            invoice_display_name: "Card filter",
            properties: {amount: "90"}
          }
        ]
      },
      {
        applied_pricing_unit: applied_pricing_unit_args,
        billable_metric_id: sum_billable_metric.id,
        charge_model: "graduated",
        pay_in_advance: true,
        invoiceable: false,
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

  let(:fixed_charges_args) do
    [
      {
        add_on_id: add_on.id,
        charge_model: "standard"
      }
    ]
  end

  let(:applied_pricing_unit_args) do
    {
      code: pricing_unit.code,
      conversion_rate: rand(0.1..5.0)
    }
  end

  let(:usage_thresholds_args) do
    [
      {
        threshold_display_name: "Threshold 1",
        amount_cents: 1_000
      },
      {
        threshold_display_name: "Threshold 2",
        amount_cents: 10_000
      },
      {
        threshold_display_name: "Threshold 3",
        amount_cents: 100,
        recurring: true
      }
    ]
  end

  describe "#call" do
    subject(:result) { plans_service.call }

    before do
      allow(SegmentTrackJob).to receive(:perform_later)
    end

    it "creates a plan" do
      expect { plans_service.call }
        .to change(Plan, :count).by(1)

      plan = Plan.order(:created_at).last
      expect(SendWebhookJob).to have_been_enqueued.with("plan.created", plan)
      expect(plan.taxes.pluck(:code)).to eq([plan_tax.code])
      expect(plan.invoice_display_name).to eq(plan_invoice_display_name)
    end

    context "when send_webhook is false" do
      it "does not enqueue the plan.created webhook but still produces the activity log" do
        result = described_class.call(create_args, send_webhook: false)

        expect(SendWebhookJob).not_to have_been_enqueued.with("plan.created", result.plan)
        expect(Utils::ActivityLog).to have_produced("plan.created").after_commit.with(result.plan)
      end
    end

    it "does not create minimum commitment" do
      plans_service.call

      plan = Plan.order(:created_at).last

      expect(plan.minimum_commitment).to be_nil
    end

    context "without premium license" do
      it "does not create progressive billing thresholds" do
        plans_service.call

        plan = Plan.order(:created_at).last

        expect(plan.usage_thresholds.count).to eq(0)
      end

      it "does not create applied pricing units" do
        expect { result }.not_to change(AppliedPricingUnit, :count)
      end
    end

    context "with premium license", :premium do
      context "when progressive billing premium integration is not present" do
        it "does not create progressive billing thresholds" do
          plans_service.call

          plan = Plan.order(:created_at).last

          expect(plan.usage_thresholds.count).to eq(0)
        end
      end

      context "when progressive billing premium integration is present" do
        before do
          organization.update!(premium_integrations: ["progressive_billing"])
        end

        it "creates progressive billing thresholds" do
          plans_service.call

          plan = Plan.order(:created_at).last
          usage_thresholds = plan.usage_thresholds.order(threshold_display_name: :asc)

          expect(plan.usage_thresholds.count).to eq(3)
          expect(usage_thresholds.first).to have_attributes(amount_cents: 1_000)
          expect(usage_thresholds.second).to have_attributes(amount_cents: 10_000)
          expect(usage_thresholds.third).to have_attributes(amount_cents: 100)
        end
      end

      context "when applied pricing params provided" do
        context "when params are valid" do
          it "creates applied pricing units" do
            expect { result }.to change(AppliedPricingUnit, :count).by(2)
          end
        end

        context "when params are invalid" do
          let(:applied_pricing_unit_args) do
            {code: "non-existing-code"}
          end

          it "fails with a validation error" do
            expect(result).to be_failure
            expect(result.error).to be_a(BaseService::ValidationFailure)

            expect(result.error.messages).to match(
              conversion_rate: ["value_is_mandatory", "is not a number"],
              pricing_unit: ["relation_must_exist"]
            )
          end

          it "does not create applied pricing unit" do
            expect { result }.not_to change(AppliedPricingUnit, :count)
          end

          it "does not create plan" do
            expect { result }.not_to change(Plan, :count)
          end
        end
      end
    end

    it "creates charges" do
      plans_service.call

      plan = Plan.order(:created_at).last
      expect(plan.charges.count).to eq(2)

      standard_charge = plan.charges.standard.first
      graduated_charge = plan.charges.graduated.first

      expect(standard_charge).to have_attributes(
        organization_id: organization.id,
        pay_in_advance: false,
        prorated: false,
        min_amount_cents: 0,
        invoiceable: true,
        properties: {"amount" => "0"}
      )
      expect(standard_charge.taxes.pluck(:code)).to eq([charge_tax.code])
      expect(standard_charge.filters.first).to have_attributes(
        invoice_display_name: "Card filter",
        properties: {"amount" => "90"}
      )
      expect(standard_charge.filters.first.values.first).to have_attributes(
        billable_metric_filter_id: billable_metric_filter.id,
        values: ["card"]
      )

      expect(graduated_charge).to have_attributes(
        organization_id: organization.id,
        pay_in_advance: true,
        invoiceable: true,
        prorated: false
      )
    end

    it "auto-generates charge codes when not provided" do
      plan = result.plan
      charges = plan.charges.order(:created_at)

      expect(charges.first.code).to eq(billable_metric.code)
      expect(charges.second.code).to eq(sum_billable_metric.code)
    end

    it "creates fixed charges" do
      plan = result.plan
      expect(plan.fixed_charges.count).to eq(1)

      fixed_charge = plan.fixed_charges.first
      expect(fixed_charge).to have_attributes(
        organization_id: organization.id,
        add_on_id: add_on.id,
        charge_model: "standard",
        pay_in_advance: false,
        prorated: false,
        units: 0,
        properties: {"amount" => "0"}
      )
    end

    it "auto-generates fixed charge codes when not provided" do
      plan = result.plan

      expect(plan.fixed_charges.first.code).to eq(add_on.code)
    end

    it "calls SegmentTrackJob" do
      plan = plans_service.call.plan

      expect(SegmentTrackJob).to have_received(:perform_later).with(
        membership_id: CurrentContext.membership,
        event: "plan_created",
        properties: {
          code: plan.code,
          name: plan.name,
          invoice_display_name: plan.invoice_display_name,
          description: plan.description,
          plan_interval: plan.interval,
          plan_amount_cents: plan.amount_cents,
          plan_period: "arrears",
          trial: plan.trial_period,
          nb_charges: 2,
          nb_standard_charges: 1,
          nb_percentage_charges: 0,
          nb_graduated_charges: 1,
          nb_package_charges: 0,
          nb_fixed_charges: 1,
          nb_standard_fixed_charges: 1,
          nb_graduated_fixed_charges: 0,
          nb_volume_fixed_charges: 0,
          organization_id: plan.organization_id,
          parent_id: nil
        }
      )
    end

    context "when bill_charges_monthly is true" do
      context "when plan is yearly" do
        let(:create_args) do
          super().merge(interval: "yearly", bill_charges_monthly: true)
        end

        it "persists bill_charges_monthly" do
          plan = result.plan
          expect(plan.bill_charges_monthly).to eq(true)
        end

        context "when not provided" do
          let(:create_args) do
            super().merge(interval: "yearly").except(:bill_charges_monthly)
          end

          it "defaults to false" do
            plan = result.plan
            expect(plan.bill_charges_monthly).to eq(false)
          end
        end
      end

      context "when plan is semiannual" do
        let(:create_args) do
          super().merge(interval: "semiannual", bill_charges_monthly: true)
        end

        it "persists bill_charges_monthly" do
          plan = result.plan
          expect(plan.bill_charges_monthly).to eq(true)
        end

        context "when not provided" do
          let(:create_args) do
            super().merge(interval: "semiannual").except(:bill_charges_monthly)
          end

          it "defaults to false" do
            plan = result.plan
            expect(plan.bill_charges_monthly).to eq(false)
          end
        end
      end

      context "when plan is monthly" do
        let(:create_args) do
          super().merge(interval: "monthly", bill_charges_monthly: true)
        end

        it "ignores the flag and sets it to nil" do
          plan = result.plan
          expect(plan.bill_charges_monthly).to be_nil
        end
      end
    end

    describe "when bill_fixed_charges_monthly is true" do
      context "when plan is yearly" do
        let(:create_args) do
          super().merge(interval: "yearly", bill_fixed_charges_monthly: true)
        end

        it "persists bill_fixed_charges_monthly" do
          plan = result.plan
          expect(plan.bill_fixed_charges_monthly).to eq(true)
        end

        context "when not provided" do
          let(:create_args) do
            super().merge(interval: "yearly").except(:bill_fixed_charges_monthly)
          end

          it "defaults to false" do
            plan = result.plan
            expect(plan.bill_fixed_charges_monthly).to eq(false)
          end
        end
      end

      context "when plan is semiannual" do
        let(:create_args) do
          super().merge(interval: "semiannual", bill_fixed_charges_monthly: true)
        end

        it "persists bill_fixed_charges_monthly" do
          plan = result.plan
          expect(plan.bill_fixed_charges_monthly).to eq(true)
        end

        context "when not provided" do
          let(:create_args) do
            super().merge(interval: "semiannual").except(:bill_fixed_charges_monthly)
          end

          it "defaults to false" do
            plan = result.plan
            expect(plan.bill_fixed_charges_monthly).to eq(false)
          end
        end
      end

      context "when plan is monthly" do
        let(:create_args) do
          super().merge(interval: "monthly", bill_fixed_charges_monthly: true)
        end

        it "ignores the flag and sets it to nil" do
          plan = result.plan
          expect(plan.bill_fixed_charges_monthly).to be_nil
        end
      end
    end

    it "produces an activity log" do
      result = described_class.call(create_args)

      expect(Utils::ActivityLog).to have_produced("plan.created").after_commit.with(result.plan)
    end

    context "when premium", :premium do
      let(:charges_args) do
        [
          {
            billable_metric_id: billable_metric.id,
            charge_model: "standard",
            min_amount_cents: 100,
            tax_codes: [charge_tax.code]
          },
          {
            billable_metric_id: sum_billable_metric.id,
            charge_model: "graduated_percentage",
            pay_in_advance: true,
            invoiceable: false,
            regroup_paid_fees: "invoice",
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

      it "saves premium attributes" do
        plan = plans_service.call.plan

        expect(plan.minimum_commitment).to have_attributes(
          {
            amount_cents: minimum_commitment_amount_cents,
            invoice_display_name: minimum_commitment_invoice_display_name
          }
        )

        expect(plan.charges.standard.first).to have_attributes(
          {
            organization_id: organization.id,
            pay_in_advance: false,
            min_amount_cents: 100,
            invoiceable: true
          }
        )

        expect(plan.charges.graduated_percentage.first).to have_attributes(
          {
            organization_id: organization.id,
            pay_in_advance: true,
            invoiceable: false,
            regroup_paid_fees: "invoice",
            charge_model: "graduated_percentage"
          }
        )
      end
    end

    context "with code already used by a deleted plan" do
      it "creates a plan with the same code" do
        create(:plan, organization:, code: "new_plan", deleted_at: Time.current)

        expect { plans_service.call }.to change(Plan, :count).by(1)

        plans = organization.plans.with_discarded
        expect(plans.count).to eq(2)
        expect(plans.pluck(:code).uniq).to eq(["new_plan"])
      end
    end

    context "with validation error" do
      let(:plan_name) { nil }

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:name]).to eq(["value_is_mandatory"])
      end

      context "with invalid charges" do
        let(:plan_name) { "Some plan name" }

        let(:charges_args) do
          [
            {
              applied_pricing_unit: applied_pricing_unit_args,
              billable_metric_id: billable_metric.id,
              charge_model: "custom_properties",
              min_amount_cents: 100,
              tax_codes: [charge_tax.code],
              filters: []
            }
          ]
        end

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:charge_model]).to eq(["value_is_invalid"])
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
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:charge_model]).to eq(["graduated_percentage_requires_premium_license"])
        end
      end

      context "with invalid interval" do
        let(:interval) { "daily" }

        it "returns an error" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages[:interval]).to eq(["value_is_invalid"])
        end
      end
    end

    context "with metrics from other organization" do
      let(:billable_metric) { create(:billable_metric) }

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("billable_metrics_not_found")
      end
    end

    context "with add ons from other organization" do
      let(:add_on) { create(:add_on) }

      let(:create_args) do
        {
          name: plan_name,
          invoice_display_name: plan_invoice_display_name,
          organization_id: organization.id,
          code: "new_plan",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 200,
          amount_currency: "EUR",
          fixed_charges: fixed_charges_args
        }
      end

      let(:fixed_charges_args) do
        [
          {
            add_on_id: add_on.id,
            charge_model: "standard"
          }
        ]
      end

      it "returns an error" do
        expect(result).not_to be_success
        expect(result.error.error_code).to eq("add_ons_not_found")
      end
    end
  end

  describe "#bill_charges_monthly" do
    subject(:method_call) { plans_service.send(:bill_charges_monthly, create_args) }

    let(:create_args) do
      super().merge(interval:, bill_charges_monthly:)
    end

    context "when bill_charges_monthly is false" do
      let(:bill_charges_monthly) { false }

      context "when plan is yearly" do
        let(:interval) { "yearly" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is semiannual" do
        let(:interval) { "semiannual" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is monthly" do
        let(:interval) { "monthly" }

        it "ignores the flag and sets it to nil" do
          expect(subject).to be_nil
        end
      end
    end

    context "when bill_charges_monthly is true" do
      let(:bill_charges_monthly) { true }

      context "when plan is yearly" do
        let(:interval) { "yearly" }

        it "returns the correct value" do
          expect(subject).to eq(true)
        end
      end

      context "when plan is semiannual" do
        let(:interval) { "semiannual" }

        it "returns the correct value" do
          expect(subject).to eq(true)
        end
      end

      context "when plan is monthly" do
        let(:interval) { "monthly" }

        it "ignores the flag and sets it to nil" do
          expect(subject).to be_nil
        end
      end
    end

    context "when bill_charges_monthly is nil" do
      let(:bill_charges_monthly) { nil }

      context "when plan is yearly" do
        let(:interval) { "yearly" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is semiannual" do
        let(:interval) { "semiannual" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is monthly" do
        let(:interval) { "monthly" }

        it "ignores the flag and sets it to nil" do
          expect(subject).to be_nil
        end
      end
    end

    context "when bill_charges_monthly is not set" do
      let(:bill_charges_monthly) { nil }

      before { create_args.delete(:bill_charges_monthly) }

      context "when plan is yearly" do
        let(:interval) { "yearly" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is semiannual" do
        let(:interval) { "semiannual" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is monthly" do
        let(:interval) { "monthly" }

        it "ignores the flag and sets it to nil" do
          expect(subject).to be_nil
        end
      end
    end
  end

  describe "#bill_fixed_charges_monthly" do
    subject(:method_call) { plans_service.send(:bill_fixed_charges_monthly, create_args) }

    let(:create_args) do
      super().merge(interval:, bill_fixed_charges_monthly:)
    end

    context "when bill_fixed_charges_monthly is false" do
      let(:bill_fixed_charges_monthly) { false }

      context "when plan is yearly" do
        let(:interval) { "yearly" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is semiannual" do
        let(:interval) { "semiannual" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is monthly" do
        let(:interval) { "monthly" }

        it "ignores the flag and sets it to nil" do
          expect(subject).to be_nil
        end
      end
    end

    context "when bill_fixed_charges_monthly is true" do
      let(:bill_fixed_charges_monthly) { true }

      context "when plan is yearly" do
        let(:interval) { "yearly" }

        it "returns the correct value" do
          expect(subject).to eq(true)
        end
      end

      context "when plan is semiannual" do
        let(:interval) { "semiannual" }

        it "returns the correct value" do
          expect(subject).to eq(true)
        end
      end

      context "when plan is monthly" do
        let(:interval) { "monthly" }

        it "ignores the flag and sets it to nil" do
          expect(subject).to be_nil
        end
      end
    end

    context "when bill_fixed_charges_monthly is nil" do
      let(:bill_fixed_charges_monthly) { nil }

      context "when plan is yearly" do
        let(:interval) { "yearly" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is semiannual" do
        let(:interval) { "semiannual" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is monthly" do
        let(:interval) { "monthly" }

        it "ignores the flag and sets it to nil" do
          expect(subject).to be_nil
        end
      end
    end

    context "when bill_fixed_charges_monthly is not set" do
      let(:bill_fixed_charges_monthly) { nil }

      before { create_args.delete(:bill_fixed_charges_monthly) }

      context "when plan is yearly" do
        let(:interval) { "yearly" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is semiannual" do
        let(:interval) { "semiannual" }

        it "returns the correct value" do
          expect(subject).to eq(false)
        end
      end

      context "when plan is monthly" do
        let(:interval) { "monthly" }

        it "ignores the flag and sets it to nil" do
          expect(subject).to be_nil
        end
      end
    end
  end

  describe "metadata" do
    let(:create_args) do
      {
        name: plan_name,
        organization_id: organization.id,
        code: "plan_with_metadata",
        interval: "monthly",
        pay_in_advance: false,
        amount_cents: 100,
        amount_currency: "EUR",
        charges: [],
        metadata: {key1: "value1", key2: "value2"}
      }
    end

    it "creates plan with metadata" do
      result = plans_service.call

      expect(result).to be_success
      expect(result.plan.metadata).to be_present
      expect(result.plan.metadata.value).to eq("key1" => "value1", "key2" => "value2")
    end

    context "when metadata is empty" do
      let(:create_args) do
        {
          name: plan_name,
          organization_id: organization.id,
          code: "plan_with_empty_metadata",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 100,
          amount_currency: "EUR",
          charges: [],
          metadata: {}
        }
      end

      it "creates plan with empty metadata" do
        result = plans_service.call

        expect(result).to be_success
        expect(result.plan.metadata).to be_present
        expect(result.plan.metadata.value).to eq({})
      end
    end

    context "when metadata is not provided" do
      let(:create_args) do
        {
          name: plan_name,
          organization_id: organization.id,
          code: "plan_without_metadata",
          interval: "monthly",
          pay_in_advance: false,
          amount_cents: 100,
          amount_currency: "EUR",
          charges: []
        }
      end

      it "creates plan without metadata" do
        result = plans_service.call

        expect(result).to be_success
        expect(result.plan.metadata).to be_nil
      end
    end
  end
end
