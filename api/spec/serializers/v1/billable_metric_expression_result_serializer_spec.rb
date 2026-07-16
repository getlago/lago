# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::BillableMetricExpressionResultSerializer do
  subject(:serializer) { described_class.new(billable_metric_expression_result, root_name: "expression_result") }

  let(:billable_metric_expression_result) { BaseService::Result.new.tap { it.evaluation_result = "1.0" } }
  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the object" do
    expect(result["expression_result"]["value"]).to eq("1.0")
  end
end
