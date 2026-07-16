# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::QuoteVersions::VoidReasonEnum do
  it "enumerizes all the void reasons" do
    expect(described_class.values.keys)
      .to match_array(%w[manual superseded cascade_of_expired cascade_of_voided])
  end
end
