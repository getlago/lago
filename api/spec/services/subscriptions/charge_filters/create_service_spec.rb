# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::ChargeFilters::CreateService do
  subject(:service) { described_class.new(subscription:, charge:, params:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:billable_metric_filter) { create(:billable_metric_filter, billable_metric:) }
  let(:subscription) { create(:subscription, customer:, plan:) }
  let(:charge) { create(:standard_charge, plan:, organization:, billable_metric:) }
  let(:params) do
    {
      invoice_display_name: "New Filter",
      properties: {amount: "100"},
      values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
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

      it "creates a charge override" do
        expect { service.call }.to change(Charge, :count).by(1)
      end

      it "creates a charge filter on the charge override" do
        expect { service.call }.to change(ChargeFilter, :count).by(1)
      end

      it "returns the charge filter" do
        result = service.call

        expect(result).to be_success
        expect(result.charge_filter).to be_a(ChargeFilter)
        expect(result.charge_filter.invoice_display_name).to eq("New Filter")
        expect(result.charge_filter.properties).to eq({"amount" => "100"})
      end

      it "associates the filter with the charge override" do
        result = service.call

        charge_override = subscription.reload.plan.charges.first
        expect(result.charge_filter.charge_id).to eq(charge_override.id)
      end

      context "when subscription already has a plan override" do
        let(:overridden_plan) { create(:plan, organization:, parent: plan) }
        let(:subscription) { create(:subscription, customer:, plan: overridden_plan) }

        it "does not create a new plan" do
          expect { service.call }.not_to change(Plan, :count)
        end

        it "creates the charge override on the existing overridden plan" do
          result = service.call

          expect(result.charge_filter.charge.plan_id).to eq(overridden_plan.id)
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

        context "when charge override already has a filter with the same values" do
          before do
            filter = create(:charge_filter, charge: existing_charge_override, organization:)
            create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values: [billable_metric_filter.values.first], organization:)
          end

          it "returns validation failure" do
            result = service.call

            expect(result).not_to be_success
            expect(result.error).to be_a(BaseService::ValidationFailure)
            expect(result.error.messages).to eq({values: ["value_already_exists"]})
          end
        end
      end

      context "when parent charge has the same filter values" do
        before do
          filter = create(:charge_filter, charge:, organization:)
          create(:charge_filter_value, charge_filter: filter, billable_metric_filter:, values: [billable_metric_filter.values.first], organization:)
        end

        it "returns validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({values: ["value_already_exists"]})
        end
      end

      context "when values are missing" do
        let(:params) do
          {
            invoice_display_name: "New Filter",
            properties: {amount: "100"},
            values: {}
          }
        end

        it "returns validation failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
          expect(result.error.messages).to eq({values: ["value_is_mandatory"]})
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

        it "returns not found failure" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.resource).to eq("charge")
        end
      end
    end
  end
end
