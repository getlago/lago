# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customers::Metadata::UpdateService do
  subject(:update_service) { described_class.new(customer:, params:) }

  let(:customer) { create(:customer) }
  let(:customer_metadata) { create(:customer_metadata, customer:) }
  let(:another_customer_metadata) { create(:customer_metadata, customer:, key: "test", value: "1") }
  let(:params) do
    [
      {
        id: customer_metadata.id,
        key: "new key",
        value: "new value",
        display_in_invoice: true
      },
      {
        key: "Added key",
        value: "Added value",
        display_in_invoice: true
      }
    ]
  end

  describe "#call" do
    before do
      customer_metadata
      another_customer_metadata
    end

    it "updates existing metadata" do
      result = update_service.call

      metadata_keys = result.customer.metadata.pluck(:key)
      metadata_ids = result.customer.metadata.pluck(:id)

      expect(result.customer.metadata.count).to eq(2)
      expect(metadata_keys).to include("new key")
      expect(metadata_ids).to include(customer_metadata.id)
    end

    it "adds new metadata" do
      result = update_service.call

      metadata_keys = result.customer.metadata.pluck(:key)

      expect(result.customer.metadata.count).to eq(2)
      expect(metadata_keys).to include("Added key")
    end

    it "sanitizes not needed metadata" do
      result = update_service.call

      metadata_ids = result.customer.metadata.pluck(:id)

      expect(result.customer.metadata.count).to eq(2)
      expect(metadata_ids).not_to include(another_customer_metadata.id)
    end
  end
end
