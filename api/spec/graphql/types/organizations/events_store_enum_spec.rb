# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Organizations::EventsStoreEnum do
  it "has the correct values" do
    expect(described_class.values.keys).to eq(Organization::EVENTS_STORES.values)
  end
end
