# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ChargeFilters::UpdateOrOverrideService do
  subject(:service) { described_class.new(subscription:, charge:, charge_filter:, params:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
  let(:charge_filter) do
    create(:charge_filter, charge:, organization:, properties: {amount: "50"}).tap do |filter|
      create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values: [billable_metric_filter.values.first], organization:)
    end
  end
  let(:params) do
    {
      invoice_display_name: "Overridden Filter",
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
        charge_filter
        subscription
      end

      it "creates a plan override" do
        expect { service.call }.to change(Plan, :count).by(1)

        new_plan = subscription.reload.plan
        expect(new_plan.parent_id).to eq(plan.id)
      end

      it "creates a charge override" do
        expect { service.call }.to change(Charge, :count).by(1)
      end

      it "creates a charge filter override" do
        expect { service.call }.to change(ChargeFilter, :count).by(1)
      end

      it "returns the charge filter with overridden properties" do
        result = service.call

        expect(result).to be_success
        expect(result.charge_filter).to be_a(ChargeFilter)
        expect(result.charge_filter.invoice_display_name).to eq("Overridden Filter")
        expect(result.charge_filter.properties).to eq({"amount" => "150"})
      end

      it "preserves the filter values" do
        result = service.call

        expect(result.charge_filter.to_h).to eq(charge_filter.to_h)
      end

      context "when subscription already has a plan override" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }

        it "does not create a new plan" do
          expect { service.call }.not_to change(Plan, :count)
        end
      end

      context "when charge override already exists" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }
        let!(:existing_charge_override) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge, code: charge.code) }

        it "does not create a new charge" do
          expect { service.call }.not_to change(Charge, :count)
        end

        it "creates filter on the existing charge override" do
          result = service.call

          expect(result.charge_filter.charge_id).to eq(existing_charge_override.id)
        end
      end

      context "when charge filter override already exists" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }
        let!(:existing_charge_override) { create(:standard_charge, plan: overridden_plan, organization:, billable_metric:, parent: charge, code: charge.code) }
        let!(:existing_filter_override) do
          create(:charge_filter, charge: existing_charge_override, organization:, properties: {amount: "75"}).tap do |filter|
            create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values: [billable_metric_filter.values.first], organization:)
          end
        end

        it "does not create a new charge filter" do
          expect { service.call }.not_to change(ChargeFilter, :count)
        end

        it "updates the existing filter override" do
          result = service.call

          expect(result.charge_filter.id).to eq(existing_filter_override.id)
          expect(result.charge_filter.invoice_display_name).to eq("Overridden Filter")
          expect(result.charge_filter.properties).to eq({"amount" => "150"})
        end
      end

      context "when only updating invoice_display_name" do
        let(:params) { {invoice_display_name: "Display Name Only"} }

        it "updates only the invoice_display_name" do
          result = service.call

          expect(result.charge_filter.invoice_display_name).to eq("Display Name Only")
        end
      end

      context "when subscription does not exist" do
        let(:subscription) { nil }

        it "returns not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("subscription")
        end
      end

      context "when charge does not exist" do
        let(:charge) { nil }
        let(:charge_filter) { nil }

        it "returns not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("charge")
        end
      end

      context "when charge filter does not exist" do
        let(:charge_filter) { nil }

        it "returns not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("charge_filter")
        end
      end
    end
  end
end
