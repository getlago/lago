# frozen_string_literal: true

require "rails_helper"

RSpec.describe PricingUnit do
  subject { build(:pricing_unit) }

  it { is_expected.to belong_to(:organization) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_presence_of(:short_name) }
  it { is_expected.to validate_length_of(:description).is_at_most(600) }
  it { is_expected.to validate_length_of(:short_name).is_at_most(3) }
  it { is_expected.to validate_uniqueness_of(:code).scoped_to(:organization_id) }

  describe "#exponent" do
    subject { pricing_unit.exponent }

    let(:pricing_unit) { build_stubbed(:pricing_unit) }

    it "returns 2" do
      expect(subject).to eq(2)
    end
  end

  describe "#subunit_to_unit" do
    subject { pricing_unit.subunit_to_unit }

    let(:pricing_unit) { build_stubbed(:pricing_unit) }

    it "returns 10 raised to the power of exponent" do
      expect(subject).to eq(100)
    end
  end
end
