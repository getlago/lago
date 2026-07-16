# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceCustomSection do
  subject(:invoice_custom_section) { create(:invoice_custom_section) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:customer_applied_invoice_custom_sections).dependent(:destroy) }
  it { is_expected.to have_many(:billing_entity_applied_invoice_custom_sections).dependent(:destroy) }

  describe "enums" do
    it "defines section_type enum with correct values" do
      expect(described_class.section_types).to eq(
        "manual" => "manual",
        "system_generated" => "system_generated"
      )
    end

    it "has manual as the default section_type" do
      expect(invoice_custom_section.section_type).to eq("manual")
    end
  end
end
