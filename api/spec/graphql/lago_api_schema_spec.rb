# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoApiSchema do
  it "matches the dumped graphql schema" do
    expect(described_class.to_definition.rstrip).to eq(File.read(Rails.root.join("schema.graphql")).rstrip)
  end

  it "matches the dumped JSON schema" do
    actual_json_schema = JSON.parse(described_class.to_json)
    expected_json_schema = JSON.parse(File.read(Rails.root.join("schema.json")))

    expect(actual_json_schema).to eq(expected_json_schema)
  end
end
