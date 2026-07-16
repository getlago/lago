# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::OrderForms::StatusEnum do
  it "exposes all enum values" do
    expect(described_class.values.keys).to match_array(OrderForm::STATUSES.keys.map(&:to_s))
  end
end
