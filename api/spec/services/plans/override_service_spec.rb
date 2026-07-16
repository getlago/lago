# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plans::OverrideService do
  subject(:override_service) { described_class.new(plan: parent_plan, params:, subscription:) }

  let(:subscription) { nil }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  describe "#call", :premium do
    let(:parent_plan) { create(:plan, organization:) }
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:add_on) { create(:add_on, organization:) }
    let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }
    let(:tax) { create(:tax, organization:) }

    let(:charge) do
      create(
        :standard_charge,
        plan: parent_plan,
        billable_metric:,
        properties: {amount: "300"}
      )
    end

    let(:fixed_charge) do
      create(:fixed_charge, plan: parent_plan, add_on:, properties: {amount: "300"})
    end

    let(:usage_threshold) { create(:usage_threshold, plan: parent_plan) }

    let(:filter) do
      create(
        :charge_filter,
        charge:,
        properties: {amount: "10"}
      )
    end

    let(:filter_value) do
      create(
        :charge_filter_value,
        charge_filter: filter,
        billable_metric_filter:,
        values: [billable_metric_filter.values.first]
      )
    end

    let(:params) do
      {
        amount_cents: 300,
        amount_currency: "USD",
        invoice_display_name: "invoice display name",
        name: "overridden name",
        description: "overridden description",
        trial_period: 20,
        tax_codes: [tax.code],
        charges: charges_params,
        fixed_charges: fixed_charges_params,
        usage_thresholds: usage_thresholds_args,
        minimum_commitment: minimum_commitment_params
      }
    end

    let(:minimum_commitment_params) do
      {
        amount_cents: minimum_commitment_amount_cents,
        invoice_display_name: minimum_commitment_invoice_display_name,
        tax_codes: [tax.code]
      }
    end

    let(:minimum_commitment_invoice_display_name) { "Minimum spending" }
    let(:minimum_commitment_amount_cents) { 100 }

    let(:charges_params) do
      [
        {
          id: charge.id,
          min_amount_cents: 1000
        }
      ]
    end

    let(:fixed_charges_params) do
      [
        {
          id: fixed_charge.id,
          properties: {amount: "1000"}
        }
      ]
    end

    let(:usage_thresholds_args) do
      [
        {
          id: usage_threshold.id,
          threshold_display_name: "Threshold 1",
          amount_cents: 1_000
        }
      ]
    end

    before do
      organization.update!(premium_integrations: ["progressive_billing"])
      charge
      fixed_charge
      usage_threshold
      allow(SegmentTrackJob).to receive(:perform_later)
      filter_value
    end

    it "creates a plan based from the parent plan" do
      expect { override_service.call }.to change(Plan, :count).by(1)

      plan = Plan.order(:created_at).last
      expect(plan).to have_attributes(
        organization_id: organization.id,
        bill_charges_monthly: parent_plan.bill_charges_monthly,
        code: parent_plan.code,
        interval: parent_plan.interval,
        pay_in_advance: parent_plan.pay_in_advance,
        # Parent id
        parent_id: parent_plan.id,
        # Overriden attributes
        amount_cents: 300,
        amount_currency: "USD",
        description: "overridden description",
        invoice_display_name: "invoice display name",
        name: "overridden name",
        trial_period: 20
      )

      expect(plan.taxes).to contain_exactly(tax)

      expect(plan.minimum_commitment).to have_attributes(
        commitment_type: "minimum_commitment",
        amount_cents: minimum_commitment_amount_cents,
        invoice_display_name: minimum_commitment_invoice_display_name
      )

      expect(plan.usage_thresholds.first).to have_attributes(
        threshold_display_name: "Threshold 1",
        amount_cents: 1_000
      )

      expect(plan.minimum_commitment.taxes.first).to eq(tax)
    end

    it "calls SegmentTrackJob" do
      plan = override_service.call.plan

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
          nb_charges: 1,
          nb_fixed_charges: 1,
          nb_standard_charges: 1,
          nb_percentage_charges: 0,
          nb_graduated_charges: 0,
          nb_package_charges: 0,
          nb_standard_fixed_charges: 1,
          nb_graduated_fixed_charges: 0,
          nb_volume_fixed_charges: 0,
          organization_id: plan.organization_id,
          parent_id: plan.parent.id
        }
      )
    end

    it "creates charges based from the parent plan" do
      charge2 = create(
        :graduated_charge,
        plan: parent_plan,
        billable_metric:,
        properties: {
          graduated_ranges: [
            {
              from_value: 0,
              to_value: nil,
              per_unit_amount: "0.01",
              flat_amount: "0.01"
            }
          ]
        }
      )

      expect { override_service.call }.to change(Plan, :count).by(1)

      plan = Plan.order(:created_at).last
      expect(plan.charges.count).to eq(2)

      graduated = plan.charges.graduated.first
      expect(graduated).to have_attributes(
        plan_id: plan.id,
        min_amount_cents: charge2.min_amount_cents,
        properties: charge2.properties
      )

      standard = plan.charges.standard.first
      expect(standard).to have_attributes(
        amount_currency: charge.amount_currency,
        billable_metric_id: billable_metric.id,
        charge_model: charge.charge_model,
        invoiceable: charge.invoiceable,
        pay_in_advance: charge.pay_in_advance,
        prorated: charge.prorated,
        properties: charge.properties,
        # Overriden attributes
        plan_id: plan.id,
        min_amount_cents: 1000
      )
    end

    it "passes the overridden plan to charge overrides" do
      allow(Charges::OverrideService).to receive(:call).and_call_original

      result = override_service.call

      expect(Charges::OverrideService).to have_received(:call).with(
        charge:,
        params: {
          id: charge.id,
          min_amount_cents: 1000,
          plan: result.plan
        }
      )
    end

    it "creates fixed charges based from the parent plan" do
      expect { override_service.call }.to change(Plan, :count).by(1)
      plan = Plan.order(:created_at).last
      expect(plan.fixed_charges.count).to eq(1)
      expect(plan.fixed_charges.first).to have_attributes(
        add_on_id: fixed_charge.add_on_id,
        properties: {"amount" => "1000"}
      )
    end

    context "when minimum commitment is not valid" do
      let(:minimum_commitment_amount_cents) { nil }

      it "returns error" do
        expect { override_service.call }.not_to change(Plan, :count)
        expect(override_service.call).not_to be_success
      end
    end

    context "when subscription parameter is provided" do
      let(:customer) { create(:customer, organization:) }
      let(:subscription) { create(:subscription, plan: parent_plan, customer:) }

      it "creates a plan successfully with subscription parameter" do
        expect { override_service.call }.to change(Plan, :count).by(1)

        result = override_service.call
        expect(result).to be_success
        expect(result.plan.parent_id).to eq(parent_plan.id)
      end

      context "when fixed charge has apply_units_immediately set to true" do
        let(:fixed_charges_params) do
          [
            {
              id: fixed_charge.id,
              properties: {amount: "1000"},
              units: 25,
              apply_units_immediately: true
            }
          ]
        end

        before do
          allow(FixedCharges::OverrideService).to receive(:call).and_call_original
        end

        it "passes subscription parameter to FixedCharges::OverrideService" do
          override_service.call

          expect(FixedCharges::OverrideService)
            .to have_received(:call)
            .with(
              fixed_charge: fixed_charge,
              params: {
                id: fixed_charge.id,
                properties: {amount: "1000"},
                units: 25,
                apply_units_immediately: true,
                plan_id: kind_of(String)
              },
              subscription: subscription
            )
        end
      end
    end
  end
end
