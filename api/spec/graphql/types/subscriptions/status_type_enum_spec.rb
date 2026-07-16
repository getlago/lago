# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::StatusTypeEnum do
  it "exposes all enum values" do
    expect(described_class.values.keys).to match_array(%w[pending active terminated canceled incomplete])
  end
end
