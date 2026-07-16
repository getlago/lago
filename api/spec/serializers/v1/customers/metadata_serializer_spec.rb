# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Customers::MetadataSerializer do
  subject(:serializer) { described_class.new(metadata, root_name: "metadata") }

  let(:metadata) { create(:customer_metadata) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["metadata"]["lago_id"]).to eq(metadata.id)
    expect(result["metadata"]["key"]).to eq(metadata.key)
    expect(result["metadata"]["value"]).to eq(metadata.value)
    expect(result["metadata"]["display_in_invoice"]).to eq(metadata.display_in_invoice)
    expect(result["metadata"]["created_at"]).to eq(metadata.created_at.iso8601)
  end
end
