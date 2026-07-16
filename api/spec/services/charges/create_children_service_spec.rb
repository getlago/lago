# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::CreateChildrenService do
  subject(:create_service) { described_class.new(child_ids:, charge:, payload:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:charge) { create(:standard_charge, organization:, plan:, billable_metric:) }

  let(:child_plan) { create(:plan, organization:, parent_id:) }
  let(:parent_id) { plan.id }
  let(:child_ids) { child_plan.id }

  let(:payload) { {} }

  let(:billable_metric_filters) { create_list(:billable_metric_filter, 2, billable_metric:) }
  let(:billable_metric_filter) { billable_metric_filters.first }

  before do
    charge
    child_plan
  end

  describe "#call" do
    context "when charge is not found" do
      let(:charge) { nil }

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("charge_not_found")
      end
    end

    context "when child charge is successfully added" do
      let(:payload) do
        {
          billable_metric_id: billable_metric.id,
          charge_model: "standard",
          pay_in_advance: false,
          prorated: false,
          invoiceable: false,
          min_amount_cents: 10,
          filters: [
            {
              invoice_display_name: "Card filter",
              properties: {amount: "90"},
              values: {billable_metric_filter.key => [billable_metric_filter.values.first]}
            }
          ]
        }
      end

      it "creates new charge" do
        expect { create_service.call }.to change(Charge, :count).by(1)
      end

      it "does not touch plan" do
        freeze_time do
          expect { create_service.call }.not_to change { child_plan.reload.updated_at }
        end
      end

      it "sets correctly attributes" do
        create_service.call

        stored_charge = child_plan.reload.charges.first

        expect(stored_charge).to have_attributes(
          organization_id: organization.id,
          prorated: false,
          pay_in_advance: false,
          parent_id: charge.id,
          properties: {"amount" => "0"}
        )

        expect(stored_charge.filters.first).to have_attributes(
          invoice_display_name: "Card filter",
          properties: {"amount" => "90"}
        )

        expect(stored_charge.filters.first.values.first).to have_attributes(
          billable_metric_filter_id: billable_metric_filter.id,
          values: [billable_metric_filter.values.first]
        )
      end
    end
  end
end
