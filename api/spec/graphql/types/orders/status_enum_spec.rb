# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Orders::StatusEnum do
  it "exposes all enum values" do
    expect(described_class.values.keys).to match_array(Order::STATUSES.values)
  end
end
