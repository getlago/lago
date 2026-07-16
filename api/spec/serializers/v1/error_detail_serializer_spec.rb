# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::ErrorDetailSerializer do
  subject(:serializer) { described_class.new(error_detail, root_name: "error_detail") }

  let(:error_detail) { create(:error_detail) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["error_detail"]).to include(
      "lago_id" => error_detail.id,
      "error_code" => error_detail.error_code,
      "details" => error_detail.details
    )
  end
end
