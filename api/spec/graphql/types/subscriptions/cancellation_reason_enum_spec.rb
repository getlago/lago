# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::CancellationReasonEnum do
  it "exposes all enum values" do
    expect(described_class.values.keys).to match_array(%w[payment_failed timeout])
  end
end
