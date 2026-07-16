# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::RevenueStreams::Customers::Collection do
  subject { described_class }

  it do
    expect(subject.graphql_name).to eq("DataApiRevenueStreamsCustomers")
    expect(subject).to have_field(:collection).of_type("[DataApiRevenueStreamCustomer!]!")
    expect(subject).to have_field(:metadata).of_type("DataApiMetadata!")
  end
end
