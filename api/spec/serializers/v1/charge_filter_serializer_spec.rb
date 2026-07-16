# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::ChargeFilterSerializer do
  subject(:serializer) { described_class.new(charge_filter, root_name: "filter") }

  let(:charge_filter) { create(:charge_filter, properties:) }
  let(:properties) { {"amount" => "1000"} }
  let(:filter) { create(:billable_metric_filter) }

  let(:filter_value) do
    create(
      :charge_filter_value,
      charge_filter:,
      billable_metric_filter: filter,
      values: [filter.values.first]
    )
  end

  before { filter_value }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["filter"]["lago_id"]).to eq(charge_filter.id)
    expect(result["filter"]["charge_code"]).to eq(charge_filter.charge.code)
    expect(result["filter"]["invoice_display_name"]).to eq(charge_filter.invoice_display_name)
    expect(result["filter"]["properties"]).to eq(charge_filter.properties)
    expect(result["filter"]["values"]).to eq(
      {
        filter.key => filter_value.values
      }
    )
  end

  # TODO(pricing_group_keys): remove after deprecation of grouped_by
  context "with grouped_by" do
    let(:properties) { {"amount" => "1000", "grouped_by" => ["user_id"]} }

    it "serializes the grouped_by properties" do
      result = JSON.parse(serializer.to_json)
      expect(result["filter"]["properties"]["grouped_by"]).to eq(["user_id"])
      expect(result["filter"]["properties"]["pricing_group_keys"]).to eq(["user_id"])
    end
  end

  context "with pricing_group_keys" do
    let(:properties) { {"amount" => "1000", "pricing_group_keys" => ["user_id"]} }

    it "serializes the grouped_by properties" do
      result = JSON.parse(serializer.to_json)
      expect(result["filter"]["properties"]["grouped_by"]).to eq(["user_id"])
      expect(result["filter"]["properties"]["pricing_group_keys"]).to eq(["user_id"])
    end
  end
end
