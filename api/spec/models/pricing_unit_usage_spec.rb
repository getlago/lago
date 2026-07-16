# frozen_string_literal: true

require "rails_helper"

RSpec.describe PricingUnitUsage do
  subject { build(:pricing_unit_usage) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:fee) }
  it { is_expected.to belong_to(:pricing_unit) }

  it { is_expected.to validate_presence_of(:short_name) }
  it { is_expected.to validate_presence_of(:conversion_rate) }
  it { is_expected.to validate_numericality_of(:conversion_rate).is_greater_than(0) }

  describe ".build_from_fiat_amounts" do
    subject { described_class.build_from_fiat_amounts(amount:, unit_amount:, applied_pricing_unit:) }

    let(:pricing_unit) { create(:pricing_unit) }
    let(:applied_pricing_unit) { create(:applied_pricing_unit, pricing_unit:, conversion_rate: 3.0150695) }
    let(:amount) { 10655.243249 }
    let(:unit_amount) { 5.5423123 }

    let(:expected_attributes) do
      {
        organization: pricing_unit.organization,
        pricing_unit:,
        short_name: pricing_unit.short_name,
        conversion_rate: applied_pricing_unit.conversion_rate,
        amount_cents: 1065524,
        precise_amount_cents: 1065524.3249,
        unit_amount_cents: 554,
        precise_unit_amount: 5.5423123
      }
    end

    it "builds a new pricing unit usage with normalized amounts" do
      expect(subject)
        .to be_a(described_class)
        .and be_new_record
        .and have_attributes(expected_attributes)
    end
  end

  describe "#to_fiat_currency_cents" do
    subject { pricing_unit_usage.to_fiat_currency_cents(fiat_currency) }

    let(:pricing_unit_usage) do
      build(
        :pricing_unit_usage,
        amount_cents: 1065524,
        precise_amount_cents: 1065524.3249,
        unit_amount_cents: 550,
        conversion_rate: 0.0075
      )
    end

    let(:fiat_currency) { Money::Currency.new("USD") }

    it "returns a hash with converted amounts" do
      expect(subject).to be_a(Hash)
      expect(subject[:amount_cents]).to eq(7991)
      expect(subject[:precise_amount_cents]).to eq(7991.43)
      expect(subject[:unit_amount_cents]).to eq(4.125)
      expect(subject[:precise_unit_amount]).to eq(0.04125)
    end
  end
end
