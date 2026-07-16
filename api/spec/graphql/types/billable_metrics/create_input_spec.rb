# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::BillableMetrics::CreateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:aggregation_type).of_type("AggregationTypeEnum!")
    expect(subject).to accept_argument(:code).of_type("String!")
    expect(subject).to accept_argument(:description).of_type("String!")
    expect(subject).to accept_argument(:expression).of_type("String")
    expect(subject).to accept_argument(:field_name).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String!")
    expect(subject).to accept_argument(:recurring).of_type("Boolean")
    expect(subject).to accept_argument(:rounding_function).of_type("RoundingFunctionEnum")
    expect(subject).to accept_argument(:rounding_precision).of_type("Int")
    expect(subject).to accept_argument(:weighted_interval).of_type("WeightedIntervalEnum")
    expect(subject).to accept_argument(:filters).of_type("[BillableMetricFiltersInput!]")
  end
end
