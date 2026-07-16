# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Customers::Usage::Current do
  subject { described_class }

  it do
    expect(subject).to have_field(:from_datetime).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:to_datetime).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:issuing_date).of_type("ISO8601Date!")
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:taxes_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:total_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:charges_usage).of_type("[ChargeUsage!]!")
  end
end
