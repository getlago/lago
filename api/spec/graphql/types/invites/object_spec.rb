# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Invites::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:organization).of_type("Organization!")
    expect(subject).to have_field(:recipient).of_type("Membership!")

    expect(subject).to have_field(:email).of_type("String!")
    expect(subject).to have_field(:roles).of_type("[String!]!")
    expect(subject).to have_field(:status).of_type("InviteStatusTypeEnum!")
    expect(subject).to have_field(:token).of_type("String!")

    expect(subject).to have_field(:accepted_at).of_type("ISO8601DateTime")
    expect(subject).to have_field(:revoked_at).of_type("ISO8601DateTime")
  end
end
