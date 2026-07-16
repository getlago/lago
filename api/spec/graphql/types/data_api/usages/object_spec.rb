# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::Usages::Object do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiUsage")
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:billable_metric_code).of_type("String!")
    expect(subject).to have_field(:units).of_type("Float!")

    expect(subject).to have_field(:is_billable_metric_deleted).of_type("Boolean!")

    expect(subject).to have_field(:end_of_period_dt).of_type("ISO8601Date!")
    expect(subject).to have_field(:start_of_period_dt).of_type("ISO8601Date!")
  end
end
