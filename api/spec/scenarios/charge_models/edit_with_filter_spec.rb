# frozen_string_literal: true

require "rails_helper"

describe "Change charge model with filters" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }

  let(:plan) { create(:plan, organization:, amount_cents: 1000) }
  let(:billable_metric) { create(:billable_metric, organization:, aggregation_type: "sum_agg", field_name: "value") }

  let(:charge) { create(:standard_charge, billable_metric:, plan:) }

  let(:billable_metric_filter) do
    create(:billable_metric_filter, billable_metric:, key: "cloud", values: %w[aws gcp azure])
  end
  let(:charge_filter) { create(:charge_filter, charge:, properties: {amount: "100"}) }
  let(:charge_filter_value) { create(:charge_filter_value, charge_filter:, billable_metric_filter:, values: ["aws"]) }

  before do
    charge_filter_value
  end

  it "allows the edition of the charge filter" do
    update_plan(
      plan,
      {amount_cents: plan.amount_cents,
       name: plan.name,
       invoice_display_name: plan.invoice_display_name,
       description: plan.description,
       charges: [
         {
           billable_metric_id: billable_metric.id,
           id: charge.id,
           invoice_display_name: charge.invoice_display_name,
           charge_model: "graduated",
           properties: {
             graduated_ranges: [
               {from_value: 0, to_value: 100, per_unit_amount: "10", flat_amount: "0"},
               {from_value: 101, to_value: nil, per_unit_amount: "20", flat_amount: "0"}
             ]
           },
           filters: [
             {
               invoice_display_name: charge_filter.invoice_display_name,
               properties: {
                 graduated_ranges: [
                   {from_value: 0, to_value: 100, per_unit_amount: "12", flat_amount: "0"},
                   {from_value: 101, to_value: nil, per_unit_amount: "22", flat_amount: "0"}
                 ]
               },
               values: {
                 cloud: ["aws"]
               }
             }
           ]
         }
       ]}
    )

    plan.reload
    expect(plan.charges.first.charge_model).to eq("graduated")
    expect(plan.charges.first.filters.count).to eq(1)
    expect(plan.charges.first.filters.first.properties["graduated_ranges"][0]).to include(
      "from_value" => 0, "to_value" => 100, "per_unit_amount" => "12", "flat_amount" => "0"
    )
    expect(plan.charges.first.filters.first.properties["graduated_ranges"][1]).to include(
      "from_value" => 101, "to_value" => nil, "per_unit_amount" => "22", "flat_amount" => "0"
    )
  end
end
