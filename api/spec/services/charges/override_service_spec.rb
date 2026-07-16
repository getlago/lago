# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::OverrideService do
  subject(:override_service) { described_class.new(charge:, params:) }

  let(:organization) { create(:organization) }

  describe "#call" do
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:tax) { create(:tax, organization:) }

    let(:charge) do
      create(
        :standard_charge,
        organization:,
        billable_metric:,
        properties: {amount: "300"}
      )
    end
    let(:plan) { create(:plan, organization:) }
    let(:params) do
      {
        id: charge.id,
        plan_id: plan.id,
        # invoice_display_name: 'invoice display name',
        min_amount_cents: 1000,
        properties: {amount: "200"},
        tax_codes: [tax.code]
      }
    end

    before { charge }

    context "when lago freemium" do
      it "returns without overriding the charge" do
        expect { override_service.call }.not_to change(Charge, :count)
      end
    end

    context "when lago premium", :premium do
      it "creates a charge based on the given charge" do
        applied_tax = create(:charge_applied_tax, charge:)

        expect(charge.taxes).to contain_exactly(applied_tax.tax)

        expect { override_service.call }.to change(Charge, :count).by(1)

        new_charge = Charge.order(:created_at).last
        expect(new_charge).to have_attributes(
          amount_currency: new_charge.amount_currency,
          billable_metric_id: new_charge.billable_metric.id,
          charge_model: new_charge.charge_model,
          invoiceable: new_charge.invoiceable,
          parent_id: charge.id,
          pay_in_advance: new_charge.pay_in_advance,
          prorated: new_charge.prorated,
          # Overriden attributes
          plan_id: plan.id,
          # invoice_display_name: 'invoice display name',
          min_amount_cents: 1000,
          properties: {"amount" => "200"}
        )
        expect(new_charge.taxes).to contain_exactly(tax)
      end

      context "when the plan is passed in params" do
        let(:params) do
          {
            id: charge.id,
            plan:,
            min_amount_cents: 1000,
            properties: {amount: "200"}
          }
        end

        it "creates the charge on the given plan" do
          result = override_service.call

          expect(result).to be_success
          expect(result.charge.plan).to eq(plan)
          expect(result.charge.organization).to eq(plan.organization)
        end
      end

      context "with charge filters" do
        let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }

        let(:charge) do
          create(
            :standard_charge,
            billable_metric:,
            properties: {amount: "300"}
          )
        end

        let(:filters) do
          [
            create(
              :charge_filter,
              charge:,
              properties: {amount: "10"}
            ),
            create(
              :charge_filter,
              charge:,
              properties: {amount: "20"}
            )
          ]
        end

        let(:filter_values) do
          [
            create(
              :charge_filter_value,
              charge_filter: filters.first,
              billable_metric_filter:,
              values: [billable_metric_filter.values.first]
            ),
            create(
              :charge_filter_value,
              charge_filter: filters.second,
              billable_metric_filter:,
              values: [billable_metric_filter.values.second]
            )
          ]
        end

        let(:params) do
          {
            id: charge.id,
            plan_id: plan.id,
            min_amount_cents: 1000,
            properties: {amount: "200"},
            tax_codes: [tax.code],
            filters: [
              {
                properties: {amount: "10"},
                invoice_display_name: "invoice display name",
                values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
              }
            ]
          }
        end

        before { filter_values }

        it "creates a charge based on the given charge" do
          expect { override_service.call }.to change(Charge, :count).by(1)

          charge = Charge.order(:created_at).last

          expect(charge.filters.count).to eq(1)
          expect(charge.filters.with_discarded.discarded.count).to eq(1)
          expect(charge.filters.first).to have_attributes(
            {
              invoice_display_name: "invoice display name",
              properties: {"amount" => "10"}
            }
          )
          expect(charge.filters.first.values.count).to eq(1)
          expect(charge.filters.first.values.first).to have_attributes(
            billable_metric_filter_id: billable_metric_filter.id,
            values: [billable_metric_filter.values.first]
          )
        end
      end

      context "with applied pricing unit" do
        let(:params) do
          {
            id: charge.id,
            plan_id: plan.id,
            min_amount_cents: 1000,
            properties: {amount: "200"},
            tax_codes: [tax.code],
            applied_pricing_unit: {
              conversion_rate: 5
            }
          }
        end

        before do
          create(
            :applied_pricing_unit,
            pricing_unitable: charge,
            conversion_rate: 1.1,
            pricing_unit: create(:pricing_unit, organization:)
          )
        end

        it "creates a charge based on the given charge" do
          result = override_service.call

          expect(result).to be_success
          expect(result.charge.applied_pricing_unit.conversion_rate).to eq 5
        end

        it "does not change parent charge" do
          expect { override_service.call }.not_to change { charge.reload.attributes }
        end
      end
    end
  end
end
