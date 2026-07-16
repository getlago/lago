# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::FixedCharges::Properties do
  subject { described_class }

  it { is_expected.to have_field(:amount).of_type("String") }
  it { is_expected.to have_field(:graduated_ranges).of_type("[GraduatedRange!]") }
  it { is_expected.to have_field(:volume_ranges).of_type("[VolumeRange!]") }
end
