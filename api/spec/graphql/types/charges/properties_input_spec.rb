# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Charges::PropertiesInput do
  subject { described_class }

  it do
    expect(subject).to accept_argument(:amount).of_type("String")
    expect(subject).to accept_argument(:pricing_group_keys).of_type("[String!]")
    expect(subject).to accept_argument(:presentation_group_keys).of_type("[PresentationGroupKeyInput!]")

    expect(subject).to accept_argument(:graduated_ranges).of_type("[GraduatedRangeInput!]")

    expect(subject).to accept_argument(:graduated_percentage_ranges).of_type("[GraduatedPercentageRangeInput!]")

    expect(subject).to accept_argument(:free_units).of_type("BigInt")
    expect(subject).to accept_argument(:package_size).of_type("BigInt")

    expect(subject).to accept_argument(:fixed_amount).of_type("String")
    expect(subject).to accept_argument(:free_units_per_events).of_type("BigInt")
    expect(subject).to accept_argument(:free_units_per_total_aggregation).of_type("String")
    expect(subject).to accept_argument(:per_transaction_max_amount).of_type("String")
    expect(subject).to accept_argument(:per_transaction_min_amount).of_type("String")
    expect(subject).to accept_argument(:rate).of_type("String")

    expect(subject).to accept_argument(:volume_ranges).of_type("[VolumeRangeInput!]")

    expect(subject).to accept_argument(:custom_properties).of_type("JSON")
  end
end
