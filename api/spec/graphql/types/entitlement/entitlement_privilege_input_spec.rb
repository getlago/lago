# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Entitlement::EntitlementPrivilegeInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:privilege_code).of_type("String!")
    expect(subject).to accept_argument(:value).of_type("String!")
  end
end
