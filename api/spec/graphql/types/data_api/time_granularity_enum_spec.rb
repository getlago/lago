# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::TimeGranularityEnum do
  it "enumerizes the correct values" do
    expect(described_class.values.keys).to match_array(%w[daily weekly monthly])
  end
end
