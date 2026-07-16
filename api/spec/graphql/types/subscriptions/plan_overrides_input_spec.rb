# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::PlanOverridesInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:amount_cents).of_type("BigInt")
    expect(subject).to accept_argument(:amount_currency).of_type("CurrencyEnum")
    expect(subject).to accept_argument(:charges).of_type("[ChargeOverridesInput!]")
    expect(subject).to accept_argument(:fixed_charges).of_type("[FixedChargeOverridesInput!]")
    expect(subject).to accept_argument(:description).of_type("String")
    expect(subject).to accept_argument(:minimum_commitment).of_type("CommitmentInput")
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:name).of_type("String")
    expect(subject).to accept_argument(:tax_codes).of_type("[String!]")
    expect(subject).to accept_argument(:trial_period).of_type("Float")
  end
end
