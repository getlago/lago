# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Entitlement::PlanEntitlementPrivilegeObject do
  subject { described_class }

  it do
    expect(subject).to have_field(:value).of_type("String!")
    expect(subject).to have_field(:code).of_type("String!")
    expect(subject).to have_field(:config).of_type("PrivilegeConfigObject!")
    expect(subject).to have_field(:name).of_type("String")
    expect(subject).to have_field(:value_type).of_type("PrivilegeValueTypeEnum!")
  end
end
