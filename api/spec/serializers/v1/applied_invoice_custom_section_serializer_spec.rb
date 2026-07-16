# frozen_string_literal: true

require "rails_helper"

RSpec.describe V1::AppliedInvoiceCustomSectionSerializer do
  subject(:serializer) { described_class.new(applied_invoice_custom_section) }

  let(:subscription) { create(:subscription) }
  let(:applied_invoice_custom_section) do
    create(:subscription_applied_invoice_custom_section, subscription:)
  end

  describe "#serialize" do
    let(:invoice_custom_section) { applied_invoice_custom_section.invoice_custom_section }

    it "serializes the applied invoice custom section correctly" do
      serialized_data = serializer.serialize

      expect(serialized_data[:lago_id]).to eq(applied_invoice_custom_section.id)
      expect(serialized_data[:created_at]).to eq(applied_invoice_custom_section.created_at.iso8601)
      expect(serialized_data[:invoice_custom_section_id]).to eq(applied_invoice_custom_section.invoice_custom_section_id)
      expect(serialized_data[:invoice_custom_section]).to eq(
        lago_id: invoice_custom_section.id,
        code: invoice_custom_section.code,
        name: invoice_custom_section.name,
        description: invoice_custom_section.description,
        details: invoice_custom_section.details,
        display_name: invoice_custom_section.display_name,
        organization_id: invoice_custom_section.organization_id
      )
    end
  end
end
