# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharge::AppliedTax do
  it { is_expected.to belong_to(:fixed_charge) }
  it { is_expected.to belong_to(:tax) }
  it { is_expected.to belong_to(:organization) }
end
