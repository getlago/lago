# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Commitments::Input do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:id).of_type("ID")
    expect(subject).to accept_argument(:invoice_display_name).of_type("String")
    expect(subject).to accept_argument(:amount_cents).of_type("BigInt")
    expect(subject).to accept_argument(:commitment_type).of_type("CommitmentTypeEnum")
    expect(subject).to accept_argument(:tax_codes).of_type("[String!]")
  end
end
