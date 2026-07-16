# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::InvoiceCustomSectionsResolver do
  let(:required_permission) { "invoice_custom_sections:view" }
  let(:query) do
    <<~GQL
      query() {
        invoiceCustomSections(limit: 5) {
          collection { id, name }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity) { create(:billing_entity, organization:) }
  let(:customer) { create(:customer, organization:, billing_entity:) }
  let(:invoice_custom_section_1_manual) { create(:invoice_custom_section, organization:, name: "x") }
  let(:invoice_custom_section_2_manual) { create(:invoice_custom_section, organization:, name: "a") }
  let(:invoice_custom_section_3_manual) { create(:invoice_custom_section, organization:, name: "c") }
  let(:invoice_custom_section_4_system_generated) { create(:invoice_custom_section, :system_generated, organization:, name: "not show") }

  before do
    invoice_custom_section_1_manual
    invoice_custom_section_2_manual
    invoice_custom_section_3_manual
    invoice_custom_section_4_system_generated
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoice_custom_sections:view"

  it "returns a list of sorted invoice_custom_sections: alphabetical" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:
    )

    invoice_custom_sections_response = result["data"]["invoiceCustomSections"]

    expect(invoice_custom_sections_response["collection"].count).to eq(3)
    expect(invoice_custom_sections_response["collection"].map { |ics| ics["name"] }.join("")).to eq("acx")

    expect(invoice_custom_sections_response["metadata"]["currentPage"]).to eq(1)
    expect(invoice_custom_sections_response["metadata"]["totalCount"]).to eq(3)
  end
end
