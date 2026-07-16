# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::Mrrs::Plans::Object do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiMrrPlan")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:dt).of_type("ISO8601Date!")
    expect(subject).to have_field(:plan_code).of_type("String!")
    expect(subject).to have_field(:plan_deleted_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:plan_id).of_type("ID!")
    expect(subject).to have_field(:plan_interval).of_type("PlanInterval!")
    expect(subject).to have_field(:plan_name).of_type("String!")
    expect(subject).to have_field(:active_customers_count).of_type("BigInt!")
    expect(subject).to have_field(:active_customers_share).of_type("Float!")
    expect(subject).to have_field(:mrr).of_type("Float!")
    expect(subject).to have_field(:mrr_share).of_type("Float")
  end
end
