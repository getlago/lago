# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::QuoteVersions::StatusEnum do
  it "enumerizes the quote version statuses" do
    expect(described_class.values.keys).to match_array(%w[draft approved voided])
  end
end
