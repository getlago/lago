# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::MembershipType do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:organization).of_type("Organization!")
    expect(subject).to have_field(:user).of_type("User!")

    expect(subject).to have_field(:permissions).of_type("Permissions!")
    expect(subject).to have_field(:roles).of_type("[String!]!")
    expect(subject).to have_field(:status).of_type("MembershipStatus!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:revoked_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
