# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Quotes::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:organization).of_type("Organization!")
    expect(subject).to have_field(:customer).of_type("Customer!")
    expect(subject).to have_field(:subscription).of_type("Subscription")
    expect(subject).to have_field(:current_version).of_type("QuoteVersion!")
    expect(subject).to have_field(:versions).of_type("[QuoteVersion!]!")
    expect(subject).to have_field(:number).of_type("String!")
    expect(subject).to have_field(:images).of_type("JSON!")
    expect(subject).to have_field(:order_type).of_type("OrderTypeEnum!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
