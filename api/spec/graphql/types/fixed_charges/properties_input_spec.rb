# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::FixedCharges::PropertiesInput do
  subject { described_class }

  it { is_expected.to accept_argument(:amount).of_type("String") }
  it { is_expected.to accept_argument(:graduated_ranges).of_type("[GraduatedRangeInput!]") }
  it { is_expected.to accept_argument(:volume_ranges).of_type("[VolumeRangeInput!]") }
end
