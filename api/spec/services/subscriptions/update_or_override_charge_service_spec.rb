# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::UpdateOrOverrideChargeService do
  subject(:service) { described_class.new(subscription:, charge:, params:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
  let(:params) do
    {
      invoice_display_name: "Overridden Charge",
      min_amount_cents: 500,
      properties: {amount: "150"}
    }
  end

  describe "#call" do
    context "without premium license" do
      it "returns forbidden failure" do
        result = service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end
    end

    context "with premium license", :premium do
      before do
        charge
        subscription
      end

      it "creates a plan override" do
        expect { service.call }.to change(Plan, :count).by(1)

        new_plan = subscription.reload.plan
        expect(new_plan.parent_id).to eq(plan.id)
      end

      it "creates charge override via plan override" do
        expect { service.call }.to change(Charge, :count).by(1)
      end

      it "returns the charge override with parent_id" do
        result = service.call

        expect(result.charge.parent_id).to eq(charge.id)
      end

      it "assigns the charge override to the new plan" do
        result = service.call

        expect(result.charge.plan_id).not_to eq(plan.id)
        expect(result.charge.plan.parent_id).to eq(plan.id)
      end

      it "updates the subscription to use the overridden plan" do
        service.call

        subscription.reload
        expect(subscription.plan.parent_id).to eq(plan.id)
      end

      it "applies the override params to the charge" do
        result = service.call

        expect(result.charge.invoice_display_name).to eq("Overridden Charge")
        expect(result.charge.min_amount_cents).to eq(500)
        expect(result.charge.properties).to eq({"amount" => "150"})
      end

      context "when subscription already has a plan override" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }

        it "does not create a new plan" do
          expect { service.call }.not_to change(Plan, :count)
        end

        it "creates the charge override on the existing overridden plan" do
          result = service.call

          expect(result.charge.plan_id).to eq(overridden_plan.id)
          expect(result.charge.parent_id).to eq(charge.id)
        end
      end

      context "when charge override already exists" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }
        let!(:existing_override) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge, code: charge.code) }

        it "does not create a new charge" do
          expect { service.call }.not_to change(Charge, :count)
        end

        it "updates the existing charge override" do
          result = service.call

          expect(result.charge.id).to eq(existing_override.id)
          expect(result.charge.invoice_display_name).to eq("Overridden Charge")
          expect(result.charge.min_amount_cents).to eq(500)
        end
      end

      context "when the charge passed is itself an override" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }
        let(:parent_charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
        let!(:charge) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: parent_charge, code: parent_charge.code) }

        it "does not create a new charge" do
          expect { service.call }.not_to change(Charge, :count)
        end

        it "updates the existing charge override" do
          result = service.call

          expect(result.charge.id).to eq(charge.id)
          expect(result.charge.invoice_display_name).to eq("Overridden Charge")
        end
      end

      context "when the charge passed lives directly on the overridden plan with parent_id: nil" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }
        let!(:charge) do
          create(:standard_charge, plan: overridden_plan, organization:, billable_metric:)
        end

        it "does not create a second override charge" do
          expect { service.call }.not_to change(Charge, :count)
        end

        it "updates the existing top-level charge in place" do
          result = service.call

          expect(result.charge.id).to eq(charge.id)
          expect(result.charge.parent_id).to be_nil
          expect(result.charge.plan_id).to eq(overridden_plan.id)
          expect(result.charge.invoice_display_name).to eq("Overridden Charge")
          expect(result.charge.min_amount_cents).to eq(500)
          expect(result.charge.properties).to eq({"amount" => "150"})
        end

        it "does not create a duplicate charge for the same billable metric on the overridden plan" do
          service.call

          charges_for_metric = overridden_plan.charges.where(billable_metric_id: billable_metric.id)
          expect(charges_for_metric.count).to eq(1)
          expect(charges_for_metric.first.id).to eq(charge.id)
        end
      end

      context "with tax_codes" do
        let(:tax) { create(:tax, organization:) }
        let(:params) do
          {
            invoice_display_name: "Taxed Charge",
            tax_codes: [tax.code]
          }
        end

        it "applies taxes to the charge override" do
          result = service.call

          expect(result.charge.taxes).to include(tax)
        end
      end

      context "with filters" do
        let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }
        let(:params) do
          {
            invoice_display_name: "Filtered Charge",
            filters: [
              {
                invoice_display_name: "Filter Override",
                properties: {amount: "75"},
                values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
              }
            ]
          }
        end

        it "applies filters to the charge override" do
          result = service.call

          expect(result.charge.filters).to be_present
          expect(result.charge.filters.first.invoice_display_name).to eq("Filter Override")
        end
      end
    end
  end
end
