# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::InvoiceSubscriptions::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:invoice).of_type("Invoice!")
    expect(subject).to have_field(:subscription).of_type("Subscription!")

    expect(subject).to have_field(:charge_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:subscription_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:total_amount_cents).of_type("BigInt!")

    expect(subject).to have_field(:fees).of_type("[Fee!]")

    expect(subject).to have_field(:charges_from_datetime).of_type("ISO8601DateTime")
    expect(subject).to have_field(:charges_to_datetime).of_type("ISO8601DateTime")

    expect(subject).to have_field(:in_advance_charges_from_datetime).of_type("ISO8601DateTime")
    expect(subject).to have_field(:in_advance_charges_to_datetime).of_type("ISO8601DateTime")

    expect(subject).to have_field(:from_datetime).of_type("ISO8601DateTime")
    expect(subject).to have_field(:to_datetime).of_type("ISO8601DateTime")

    expect(subject).to have_field(:accept_new_charge_fees).of_type("Boolean!")
  end
end
