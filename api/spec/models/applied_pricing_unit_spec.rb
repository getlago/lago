# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedPricingUnit do
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to belong_to(:pricing_unit) }
  it { is_expected.to belong_to(:pricing_unitable) }

  it { is_expected.to validate_presence_of(:conversion_rate) }
  it { is_expected.to validate_numericality_of(:conversion_rate).is_greater_than(0) }
end
