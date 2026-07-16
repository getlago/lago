# frozen_string_literal: true

require "rails_helper"

RSpec.describe Commitment::AppliedTax do
  it { is_expected.to belong_to(:commitment) }
  it { is_expected.to belong_to(:tax) }
  it { is_expected.to belong_to(:organization) }
end
