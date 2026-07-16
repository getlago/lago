# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Entitlement::UpdatePrivilegeInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:code).of_type("String!")
    expect(subject).to accept_argument(:config).of_type("PrivilegeConfigInput")
    expect(subject).to accept_argument(:name).of_type("String")
    expect(subject).to accept_argument(:value_type).of_type("PrivilegeValueTypeEnum")
  end
end
