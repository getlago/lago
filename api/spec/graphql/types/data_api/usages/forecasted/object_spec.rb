# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::Usages::Forecasted::Object do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiUsageForecasted")
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:amount_cents_forecast_conservative).of_type("BigInt!")
    expect(subject).to have_field(:amount_cents_forecast_optimistic).of_type("BigInt!")
    expect(subject).to have_field(:amount_cents_forecast_realistic).of_type("BigInt!")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:units).of_type("Float!")
    expect(subject).to have_field(:units_forecast_conservative).of_type("Float!")
    expect(subject).to have_field(:units_forecast_optimistic).of_type("Float!")
    expect(subject).to have_field(:units_forecast_realistic).of_type("Float!")
    expect(subject).to have_field(:end_of_period_dt).of_type("ISO8601Date!")
    expect(subject).to have_field(:start_of_period_dt).of_type("ISO8601Date!")
  end
end
