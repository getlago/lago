# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::InvoiceCustomSections::Update do
  let(:required_permission) { "invoice_custom_sections:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:mutation) do
    <<~GQL
      mutation($input: UpdateInvoiceCustomSectionInput!) {
        updateInvoiceCustomSection(input: $input) {
          id,
          code,
          name,
          description,
          details,
          displayName
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoice_custom_sections:update"

  context "when there is a invoice_custom_section" do
    let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }

    before { invoice_custom_section }

    it "updates a invoice_custom_section" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: invoice_custom_section.id,
            name: "First Invoice Custom Section",
            description: "this invoice custom section will be added in the PDF",
            details: "This is the exact information shown in the invoice",
            displayName: "Section name displayed in the invoice"
          }
        }
      )

      result_data = result["data"]["updateInvoiceCustomSection"]

      expect(result_data["id"]).to be_present
      expect(result_data["name"]).to eq("First Invoice Custom Section")
      expect(result_data["displayName"]).to eq("Section name displayed in the invoice")
      expect(result_data["code"]).to eq(invoice_custom_section.code)
      expect(result_data["description"]).to eq("this invoice custom section will be added in the PDF")
      expect(result_data["details"]).to eq("This is the exact information shown in the invoice")
    end
  end

  context "when updating to wrong values" do
    let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }

    before { invoice_custom_section }

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: invoice_custom_section.id,
            name: nil,
            description: "this invoice custom section will be added in the PDF",
            details: "This is the exact information shown in the invoice",
            displayName: "Section name displayed in the invoice"
          }
        }
      )

      expect(result["errors"]).to be_present
    end
  end
end
