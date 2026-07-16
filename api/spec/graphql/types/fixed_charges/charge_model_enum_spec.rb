# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::FixedCharges::ChargeModelEnum do
  subject { described_class }

  it "enumerates the correct charge model values" do
    expect(subject.values.keys)
      .to match_array(%w[standard graduated volume])
  end
end
