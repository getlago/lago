# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::OrderForms::VoidReasonEnum do
  it "exposes all enum values" do
    expect(described_class.values.keys).to match_array(OrderForm::VOID_REASONS.keys.map(&:to_s))
  end
end
