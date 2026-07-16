# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Entitlement::FeatureObject do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:description).of_type("String")
    expect(subject).to have_field(:name).of_type("String")

    expect(subject).to have_field(:privileges).of_type("[PrivilegeObject!]!")

    expect(subject).to have_field(:subscriptions_count).of_type("Int!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
  end
end
