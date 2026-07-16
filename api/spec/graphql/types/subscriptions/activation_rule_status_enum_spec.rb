# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Subscriptions::ActivationRuleStatusEnum do
  it "exposes all enum values" do
    expect(described_class.values.keys).to match_array(%w[inactive pending satisfied declined failed expired not_applicable])
  end
end
