# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::CreditNotes::TypeEnum do
  it "exposes all enum values" do
    expect(described_class.values.keys).to match_array(%w[credit refund offset])
  end
end
