# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedAddOn do
  subject { build(:applied_add_on) }

  it_behaves_like "paper_trail traceable"

  it { is_expected.to belong_to(:add_on) }
  it { is_expected.to belong_to(:customer) }

  it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than(0) }

  specify do
    expect(subject)
      .to validate_inclusion_of(:amount_currency)
      .in_array(described_class.currency_list)
  end
end
