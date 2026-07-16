# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ChargeModels::VolumeRangeInput do
  subject { described_class }

  it { is_expected.to accept_argument(:from_value).of_type("BigInt!") }
  it { is_expected.to accept_argument(:to_value).of_type("BigInt") }
  it { is_expected.to accept_argument(:flat_amount).of_type("String!") }
  it { is_expected.to accept_argument(:per_unit_amount).of_type("String!") }
end
