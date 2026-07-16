# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::DataApi::RevenueStreams::OrderByEnum do
  subject { described_class }

  it "supports sorting by gross revenue and net revenue" do
    expect(subject.values.keys).to match_array(%w[
      gross_revenue_amount_cents
      net_revenue_amount_cents
    ])
  end
end
