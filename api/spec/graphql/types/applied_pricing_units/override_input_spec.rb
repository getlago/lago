# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::AppliedPricingUnits::OverrideInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:conversion_rate).of_type("Float!")
  end
end
