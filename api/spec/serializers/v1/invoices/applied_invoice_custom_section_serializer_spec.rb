# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::Invoices::AppliedInvoiceCustomSectionSerializer do
  subject(:serializer) { described_class.new(applied_invoice_custom_section) }

  let(:invoice) { create(:invoice) }
  let(:applied_invoice_custom_section) do
    create(:applied_invoice_custom_section,
      invoice:,
      code: "custom_code",
      details: "custom_details",
      display_name: "Custom Display Name",
      created_at: Time.current)
  end

  describe "#serialize" do
    it "serializes the applied invoice custom section correctly" do
      serialized_data = serializer.serialize

      expect(serialized_data).to include(
        lago_id: applied_invoice_custom_section.id,
        lago_invoice_id: applied_invoice_custom_section.invoice_id,
        code: "custom_code",
        details: "custom_details",
        display_name: "Custom Display Name",
        created_at: applied_invoice_custom_section.created_at.iso8601
      )
    end
  end
end
