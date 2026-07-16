# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Payments::CreateInput do
  subject { described_class }

  it { is_expected.to accept_argument(:invoice_id).of_type("ID!") }
  it { is_expected.to accept_argument(:created_at).of_type("ISO8601DateTime!") }
  it { is_expected.to accept_argument(:reference).of_type("String!") }
  it { is_expected.to accept_argument(:amount_cents).of_type("BigInt!") }
end
