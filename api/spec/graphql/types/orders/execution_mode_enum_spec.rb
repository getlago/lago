# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Orders::ExecutionModeEnum do
  it "exposes all enum values" do
    expect(described_class.values.keys).to match_array(Order::EXECUTION_MODES.values)
  end
end
