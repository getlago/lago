# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Charges::Properties do
  subject { described_class }

  it do
    expect(subject).to have_field(:amount).of_type("String")
    expect(subject).to have_field(:pricing_group_keys).of_type("[String!]")

    expect(subject).to have_field(:graduated_ranges).of_type("[GraduatedRange!]")

    expect(subject).to have_field(:presentation_group_keys).of_type("[PresentationGroupKey!]")
    expect(subject).to have_field(:graduated_percentage_ranges).of_type("[GraduatedPercentageRange!]")

    expect(subject).to have_field(:free_units).of_type("BigInt")
    expect(subject).to have_field(:package_size).of_type("BigInt")

    expect(subject).to have_field(:fixed_amount).of_type("String")
    expect(subject).to have_field(:free_units_per_events).of_type("BigInt")
    expect(subject).to have_field(:free_units_per_total_aggregation).of_type("String")
    expect(subject).to have_field(:per_transaction_max_amount).of_type("String")
    expect(subject).to have_field(:per_transaction_min_amount).of_type("String")
    expect(subject).to have_field(:rate).of_type("String")

    expect(subject).to have_field(:volume_ranges).of_type("[VolumeRange!]")

    expect(subject).to have_field(:custom_properties).of_type("JSON")
  end
end
