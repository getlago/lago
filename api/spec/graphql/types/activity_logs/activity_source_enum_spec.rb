# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::ActivityLogs::ActivitySourceEnum do
  it "enumerates the correct values" do
    expect(described_class.values.keys).to match_array(%w[api front system])
  end
end
