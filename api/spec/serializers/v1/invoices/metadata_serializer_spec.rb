# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::Invoices::MetadataSerializer do
  subject(:serializer) { described_class.new(metadata, root_name: "metadata") }

  let(:metadata) { create(:invoice_metadata) }

  it "serializes the object" do
    result = JSON.parse(serializer.to_json)

    expect(result["metadata"]["lago_id"]).to eq(metadata.id)
    expect(result["metadata"]["key"]).to eq(metadata.key)
    expect(result["metadata"]["value"]).to eq(metadata.value)
    expect(result["metadata"]["created_at"]).to eq(metadata.created_at.iso8601)
  end
end
