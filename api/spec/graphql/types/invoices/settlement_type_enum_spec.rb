# frozen_string_literal: true

require "rails_helper"

RSpec.describe Types::Invoices::SettlementTypeEnum do
  it "exposes allowed settlement types" do
    expect(described_class.values.keys).to match_array([
      InvoiceSettlement::SETTLEMENT_TYPES.fetch(:credit_note)
    ])
  end
end
