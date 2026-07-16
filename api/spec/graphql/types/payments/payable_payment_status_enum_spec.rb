# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Payments::PayablePaymentStatusEnum do
  it "enumerizes the correct values" do
    expect(described_class.values.keys).to match_array(%w[pending processing succeeded failed])
  end
end
