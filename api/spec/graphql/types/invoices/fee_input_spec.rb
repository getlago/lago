# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Invoices::FeeInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:add_on_id).of_type("ID")
    expect(subject).to accept_argument(:description).of_type("String")
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String")
    expect(subject).to accept_argument(:tax_codes).of_type("[String!]")
    expect(subject).to accept_argument(:unit_amount_cents).of_type("BigInt")
    expect(subject).to accept_argument(:units).of_type("Float")
    expect(subject).to accept_argument(:from_datetime).of_type("ISO8601DateTime!")
    expect(subject).to accept_argument(:to_datetime).of_type("ISO8601DateTime!")
  end
end
