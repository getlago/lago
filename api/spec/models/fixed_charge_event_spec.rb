# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedChargeEvent do
  subject { build(:fixed_charge_event) }

  it { expect(described_class).to be_soft_deletable }
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:subscription) }
  it { is_expected.to belong_to(:fixed_charge) }

  it { is_expected.to validate_numericality_of(:units).is_greater_than_or_equal_to(0) }
end
