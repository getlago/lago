# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::TaxSerializer do
  subject(:serializer) { described_class.new(tax, root_name: "tax") }

  let(:tax) { create(:tax) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["tax"]).to include(
      "lago_id" => tax.id,
      "name" => tax.name,
      "code" => tax.code,
      "rate" => tax.rate,
      "description" => tax.description,
      "add_ons_count" => 0,
      "customers_count" => 0,
      "plans_count" => 0,
      "charges_count" => 0,
      "created_at" => tax.created_at.iso8601
    )
  end
end
