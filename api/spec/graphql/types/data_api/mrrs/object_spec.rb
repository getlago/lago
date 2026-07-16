# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::Mrrs::Object do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiMrr")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:ending_mrr).of_type("BigInt!")
    expect(subject).to have_field(:starting_mrr).of_type("BigInt!")
    expect(subject).to have_field(:mrr_new).of_type("BigInt!")
    expect(subject).to have_field(:mrr_expansion).of_type("BigInt!")
    expect(subject).to have_field(:mrr_contraction).of_type("BigInt!")
    expect(subject).to have_field(:mrr_churn).of_type("BigInt!")
    expect(subject).to have_field(:mrr_change).of_type("BigInt!")
    expect(subject).to have_field(:end_of_period_dt).of_type("ISO8601Date!")
    expect(subject).to have_field(:start_of_period_dt).of_type("ISO8601Date!")
  end
end
