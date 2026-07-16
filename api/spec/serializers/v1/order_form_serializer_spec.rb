# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::OrderFormSerializer do
  subject(:serializer) { described_class.new(order_form, root_name: "order_form") }

  let(:order_form) { create(:order_form) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["order_form"]).to include(
      "lago_id" => order_form.id,
      "number" => order_form.number,
      "status" => "generated",
      "void_reason" => nil,
      "expires_at" => nil,
      "signed_at" => nil,
      "voided_at" => nil,
      "lago_organization_id" => order_form.organization_id,
      "lago_customer_id" => order_form.customer_id,
      "lago_quote_id" => order_form.quote_version.quote_id,
      "lago_quote_version_id" => order_form.quote_version_id,
      "created_at" => order_form.created_at.iso8601,
      "updated_at" => order_form.updated_at.iso8601
    )
  end
end
