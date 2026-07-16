# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::AppliedPricingUnits::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:conversion_rate).of_type("Float!")
    expect(subject).to have_field(:pricing_unit).of_type("PricingUnit!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
