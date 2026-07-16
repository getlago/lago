# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Entitlement::EntitlementInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:feature_code).of_type("String!")
    expect(subject).to accept_argument(:privileges).of_type("[EntitlementPrivilegeInput!]")
  end
end
