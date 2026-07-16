# frozen_string_literal: true

RSpec.describe Plan::AppliedTax do
  subject(:plan_applied_tax) { create(:plan_applied_tax) }

  it { is_expected.to belong_to(:organization) }
end
