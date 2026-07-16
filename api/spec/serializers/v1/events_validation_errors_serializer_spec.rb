# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::EventsValidationErrorsSerializer do
  subject(:serializer) { described_class.new(errors, root_name: "events_errors") }

  let(:errors) do
    {
      invalid_code: [SecureRandom.uuid],
      missing_aggregation_property: [SecureRandom.uuid],
      missing_group_key: [SecureRandom.uuid],
      invalid_filter_values: [SecureRandom.uuid]
    }.with_indifferent_access
  end

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the validation errors" do
    expect(result["events_errors"]).to include(
      "invalid_code" => Array,
      "missing_aggregation_property" => Array,
      "missing_group_key" => Array,
      "invalid_filter_values" => Array
    )
  end
end
