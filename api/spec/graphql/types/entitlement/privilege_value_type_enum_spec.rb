# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Entitlement::PrivilegeValueTypeEnum do
  subject { described_class }

  it "defines all privilege value types" do
    Entitlement::Privilege::VALUE_TYPES.each do |value_type|
      expect(subject.values[value_type].value).to eq(value_type)
    end
  end

  it "has the correct number of values" do
    expect(subject.values.count).to eq(Entitlement::Privilege::VALUE_TYPES.count)
  end
end
