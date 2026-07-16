# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::RevenueStreams::Plans::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:plan_code).of_type("String!")
    expect(subject).to have_field(:plan_deleted_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:plan_id).of_type("ID!")
    expect(subject).to have_field(:plan_interval).of_type("PlanInterval!")
    expect(subject).to have_field(:plan_name).of_type("String!")
    expect(subject).to have_field(:customers_count).of_type("Int!")
    expect(subject).to have_field(:customers_share).of_type("Float!")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:gross_revenue_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:gross_revenue_share).of_type("Float")
    expect(subject).to have_field(:net_revenue_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:net_revenue_share).of_type("Float")
  end
end
