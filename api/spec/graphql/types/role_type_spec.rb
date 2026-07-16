# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::RoleType do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:description).of_type("String")
    expect(subject).to have_field(:admin).of_type("Boolean!")
    expect(subject).to have_field(:permissions).of_type("[PermissionEnum!]!")
    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:memberships).of_type("[Membership!]!")
  end
end
