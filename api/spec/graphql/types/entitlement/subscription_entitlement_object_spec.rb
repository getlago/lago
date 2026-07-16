# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Entitlement::SubscriptionEntitlementObject do
  subject { described_class }

  it do
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:description).of_type("String")
    expect(subject).to have_field(:name).of_type("String!")
    expect(subject).to have_field(:privileges).of_type("[SubscriptionEntitlementPrivilegeObject!]!")
  end
end
