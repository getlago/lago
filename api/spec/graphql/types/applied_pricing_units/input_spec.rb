# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::AppliedPricingUnits::Input do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:code).of_type("String!")
    expect(subject).to accept_argument(:conversion_rate).of_type("Float!")
  end
end
