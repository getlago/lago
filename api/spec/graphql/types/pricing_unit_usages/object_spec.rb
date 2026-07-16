# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::PricingUnitUsages::Object do
  subject { described_class }

  it do
    expect(subject).to have_field(:id).of_type("ID!")

    expect(subject).to have_field(:amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:conversion_rate).of_type("Float!")
    expect(subject).to have_field(:precise_amount_cents).of_type("Float!")
    expect(subject).to have_field(:precise_unit_amount).of_type("Float!")
    expect(subject).to have_field(:short_name).of_type("String!")
    expect(subject).to have_field(:unit_amount_cents).of_type("BigInt!")
    expect(subject).to have_field(:pricing_unit).of_type("PricingUnit!")

    expect(subject).to have_field(:created_at).of_type("ISO8601DateTime!")
    expect(subject).to have_field(:updated_at).of_type("ISO8601DateTime!")
  end
end
