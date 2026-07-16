# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Analytics::OverdueBalances::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:billing_entity_id).of_type("ID")
    expect(subject).to have_field(:currency).of_type("CurrencyEnum!")
    expect(subject).to have_field(:lago_invoice_ids).of_type("[String!]!")
    expect(subject).to have_field(:month).of_type("ISO8601DateTime!")
  end
end
