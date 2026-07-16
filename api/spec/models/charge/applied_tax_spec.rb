# frozen_string_literal: true

RSpec.describe Charge::AppliedTax do
  subject(:charge_applied_tax) { create(:charge_applied_tax) }

  it { is_expected.to belong_to(:charge) }
  it { is_expected.to belong_to(:tax) }
  it { is_expected.to belong_to(:organization) }
end
