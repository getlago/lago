# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::BillableMetrics::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:organization).of_type("Organization")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:description).of_type("String")
    expect(subject).to have_field(:aggregation_type).of_type("AggregationTypeEnum!")
    expect(subject).to have_field(:expression).of_type("String")
    expect(subject).to have_field(:field_name).of_type("String")
    expect(subject).to have_field(:weighted_interval).of_type("WeightedIntervalEnum")
    expect(subject).to have_field(:filters).of_type("[BillableMetricFilter!]")
    expect(subject).to have_field(:recurring).of_type("Boolean!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:deleted_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:integration_mappings).of_type("[Mapping!]")
    expect(subject).to have_field(:rounding_function).of_type("RoundingFunctionEnum")
    expect(subject).to have_field(:rounding_precision).of_type("Int")
    expect(subject).to have_field(:activity_logs).of_type("[ActivityLog!]")

    expect(subject).to have_field(:has_active_subscriptions).of_type("Boolean!")
    expect(subject).to have_field(:has_draft_invoices).of_type("Boolean!")
    expect(subject).to have_field(:has_plans).of_type("Boolean!")
    expect(subject).to have_field(:has_subscriptions).of_type("Boolean!")
  end
end
