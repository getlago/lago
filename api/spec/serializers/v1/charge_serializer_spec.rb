# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::ChargeSerializer do
  subject(:result) { JSON.parse(serializer.to_json) }

  let(:serializer) { described_class.new(charge, root_name: "charge", includes: %i[taxes]) }

  let(:charge) { create(:standard_charge, properties:) }
  let(:properties) { {"amount" => "1000"} }

  it "serializes the object" do
    expect(result["charge"]["lago_id"]).to eq(charge.id)
    expect(result["charge"]["lago_billable_metric_id"]).to eq(charge.billable_metric_id)
    expect(result["charge"]["code"]).to eq(charge.code)
    expect(result["charge"]["invoice_display_name"]).to eq(charge.invoice_display_name)
    expect(result["charge"]["billable_metric_code"]).to eq(charge.billable_metric.code)
    expect(result["charge"]["created_at"]).to eq(charge.created_at.iso8601)
    expect(result["charge"]["charge_model"]).to eq(charge.charge_model)
    expect(result["charge"]["pay_in_advance"]).to eq(charge.pay_in_advance)
    expect(result["charge"]["accepts_target_wallet"]).to eq(charge.accepts_target_wallet)
    expect(result["charge"]["properties"]).to eq(charge.properties)
    expect(result["charge"]["filters"]).to eq([])
    expect(result["charge"]["applied_pricing_unit"]).to eq nil
    expect(result["charge"]["lago_parent_id"]).to eq(charge.parent_id)
    expect(result["charge"]["taxes"]).to eq([])
  end

  context "when charge configured to use pricing units" do
    let!(:applied_pricing_unit) { create(:applied_pricing_unit, pricing_unitable: charge) }

    it "serializes the object" do
      expect(result["charge"]["lago_id"]).to eq(charge.id)
      expect(result["charge"]["lago_billable_metric_id"]).to eq(charge.billable_metric_id)
      expect(result["charge"]["invoice_display_name"]).to eq(charge.invoice_display_name)
      expect(result["charge"]["billable_metric_code"]).to eq(charge.billable_metric.code)
      expect(result["charge"]["created_at"]).to eq(charge.created_at.iso8601)
      expect(result["charge"]["charge_model"]).to eq(charge.charge_model)
      expect(result["charge"]["pay_in_advance"]).to eq(charge.pay_in_advance)
      expect(result["charge"]["properties"]).to eq(charge.properties)
      expect(result["charge"]["filters"]).to eq([])
      expect(result["charge"]["taxes"]).to eq([])

      expect(result["charge"]["applied_pricing_unit"]).to eq({
        "conversion_rate" => applied_pricing_unit.conversion_rate.to_s,
        "code" => applied_pricing_unit.pricing_unit.code
      })
    end
  end

  # TODO(pricing_group_keys): remove after deprecation of grouped_by
  context "with grouped_by" do
    let(:properties) { {"amount" => "1000", "grouped_by" => ["user_id"]} }

    it "serializes the grouped_by properties" do
      expect(result["charge"]["properties"]["grouped_by"]).to eq(["user_id"])
      expect(result["charge"]["properties"]["pricing_group_keys"]).to eq(["user_id"])
    end
  end

  context "with pricing_group_keys" do
    let(:properties) { {"amount" => "1000", "pricing_group_keys" => ["user_id"]} }

    it "serializes the grouped_by properties" do
      expect(result["charge"]["properties"]["grouped_by"]).to eq(["user_id"])
      expect(result["charge"]["properties"]["pricing_group_keys"]).to eq(["user_id"])
    end
  end
end
