# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::RevenueStreams::Plans::Collection do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiRevenueStreamsPlans")
    expect(subject).to have_field(:collection).of_type("[DataApiRevenueStreamPlan!]!")
    expect(subject).to have_field(:metadata).of_type("DataApiMetadata!")
  end
end
