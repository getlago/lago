# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoices::Metadata::UpdateService do
  subject(:update_service) { described_class.new(invoice:, params:) }

  let(:invoice) { create(:invoice) }
  let(:invoice_metadata) { create(:invoice_metadata, invoice:) }
  let(:another_invoice_metadata) { create(:invoice_metadata, invoice:, key: "test", value: "1") }
  let(:params) do
    [
      {
        id: invoice_metadata.id,
        key: "new key",
        value: "new value"
      },
      {
        key: "Added key",
        value: "Added value"
      }
    ]
  end

  describe "#call" do
    before do
      invoice_metadata
      another_invoice_metadata
    end

    it "updates existing metadata" do
      result = update_service.call

      metadata_keys = result.invoice.metadata.pluck(:key)
      metadata_ids = result.invoice.metadata.pluck(:id)

      expect(result.invoice.metadata.count).to eq(2)
      expect(metadata_keys).to include("new key")
      expect(metadata_ids).to include(invoice_metadata.id)
    end

    it "adds new metadata" do
      result = update_service.call

      metadata_keys = result.invoice.metadata.pluck(:key)

      expect(result.invoice.metadata.count).to eq(2)
      expect(metadata_keys).to include("Added key")
    end

    it "sanitizes not needed metadata" do
      result = update_service.call

      metadata_ids = result.invoice.metadata.pluck(:id)

      expect(result.invoice.metadata.count).to eq(2)
      expect(metadata_ids).not_to include(another_invoice_metadata.id)
    end
  end
end
