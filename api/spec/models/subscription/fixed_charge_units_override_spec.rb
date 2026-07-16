# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription::FixedChargeUnitsOverride, type: :model do
  subject { build(:subscription_fixed_charge_units_override) }

  it_behaves_like "paper_trail traceable"

  it { expect(described_class).to be_soft_deletable }

  describe "associations" do
    it do
      expect(subject).to belong_to(:organization)
      expect(subject).to belong_to(:subscription)
      expect(subject).to belong_to(:fixed_charge)
    end
  end

  describe "validations" do
    it do
      expect(subject).to validate_presence_of(:units)
      expect(subject).to validate_numericality_of(:units).is_greater_than_or_equal_to(0)
    end
  end
end
