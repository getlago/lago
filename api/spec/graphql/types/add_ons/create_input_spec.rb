# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::AddOns::CreateInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:amount_cents).of_type("BigInt!")
    expect(subject).to accept_argument(:amount_currency).of_type("CurrencyEnum!")
    expect(subject).to accept_argument(:code).of_type("String!")
    expect(subject).to accept_argument(:description).of_type("String")
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String!")
    expect(subject).to accept_argument(:tax_codes).of_type("[String!]")
  end
end
