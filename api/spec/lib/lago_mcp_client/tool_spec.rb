# frozen_string_literal: true

require "rails_helper"

RSpec.describe LagoMcpClient::Tool do
  subject(:tool) { described_class.new(name:, description:, input_schema:) }

  let(:name) { "get_billable_metric" }
  let(:description) { "Get a specific billable metric by its code" }
  let(:input_schema) do
    {
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "properties" => {"code" => {"type" => "string"}},
      "required" => ["code"],
      "title" => "GetBillableMetricArgs",
      "type" => "object"
    }
  end

  describe "#to_h" do
    it "returns a hash with all attributes" do
      expect(tool.to_h).to eq(
        name: "get_billable_metric",
        description: "Get a specific billable metric by its code",
        input_schema:
      )
    end
  end
end
