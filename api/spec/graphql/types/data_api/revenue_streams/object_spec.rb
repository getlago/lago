# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::RevenueStreams::Object do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiRevenueStream")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:coupons_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:gross_revenue_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:net_revenue_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:commitment_fee_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:one_off_fee_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:subscription_fee_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:usage_based_fee_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:end_of_period_dt).of_type("ISO8601Date!")
    expect(subject).to have_field(:start_of_period_dt).of_type("ISO8601Date!")
  end
end
