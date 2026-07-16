# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::RevenueStreams::Customers::Object do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiRevenueStreamCustomer")
    expect(subject).to have_field(:customer_id).of_type("ID!")
    expect(subject).to have_field(:customer_deleted_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:external_customer_id).of_type("String!")
    expect(subject).to have_field(:customer_name).of_type("String")
    expect(subject).to have_field(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:gross_revenue_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:gross_revenue_share).of_type("Float")
    expect(subject).to have_field(:net_revenue_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:net_revenue_share).of_type("Float")
  end
end
