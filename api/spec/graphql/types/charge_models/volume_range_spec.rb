# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ChargeModels::VolumeRange do
  subject { described_class }

  it { is_expected.to have_field(:from_value).of_type("BigInt!") }
  it { is_expected.to have_field(:to_value).of_type("BigInt") }
  it { is_expected.to have_field(:flat_amount).of_type("String!") }
  it { is_expected.to have_field(:per_unit_amount).of_type("String!") }
end
