# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::V1::InvoiceCustomSectionSerializer do
  subject(:serializer) { described_class.new(invoice_custom_section, root_name: "invoice_custom_section") }

  let(:invoice_custom_section) { create(:invoice_custom_section) }

  let(:result) { JSON.parse(serializer.to_json) }

  it "serializes the section" do
    expect(result["invoice_custom_section"]).to include(
      "lago_id" => invoice_custom_section.id,
      "code" => invoice_custom_section.code,
      "name" => invoice_custom_section.name,
      "description" => invoice_custom_section.description,
      "details" => invoice_custom_section.details,
      "display_name" => invoice_custom_section.display_name,
      "organization_id" => invoice_custom_section.organization_id
    )
  end
end
