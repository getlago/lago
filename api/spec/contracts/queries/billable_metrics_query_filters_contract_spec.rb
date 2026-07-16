# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::BillableMetricsQueryFiltersContract do
  subject(:result) { described_class.new.call(filters.to_h) }

  let(:filters) { {} }

  context "when filters are valid" do
    let(:filters) do
      {
        recurring: true,
        aggregation_types: ["max_agg", "count_agg"]
      }
    end

    it "is valid" do
      expect(result.success?).to be(true)
    end
  end

  context "when filters are invalid" do
    it_behaves_like "an invalid filter", :recurring, nil, ["must be filled"]
    it_behaves_like "an invalid filter", :recurring, "not_a_bool", ["must be boolean"]

    it_behaves_like "an invalid filter", :aggregation_types, nil, ["must be an array"]
    it_behaves_like "an invalid filter", :aggregation_types, "not_an_array", ["must be an array"]
    it_behaves_like "an invalid filter", :aggregation_types, [1], {0 => ["must be a string"]}
    it_behaves_like "an invalid filter", :aggregation_types, ["invalid_type"], {0 => ["must be one of: max_agg, count_agg"]}
  end
end
