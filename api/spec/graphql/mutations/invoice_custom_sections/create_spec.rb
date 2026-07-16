# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::InvoiceCustomSections::Create do
  let(:required_permission) { "invoice_custom_sections:create" }
  let(:membership) { create(:membership) }

  let(:mutation) do
    <<~GQL
      mutation($input: CreateInvoiceCustomSectionInput!) {
        createInvoiceCustomSection(input: $input) {
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
  it_behaves_like "requires permission", "invoice_custom_sections:create"

  it "creates a invoice_custom_section" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          code: "section_code",
          name: "First Invoice Custom Section",
          description: "this invoice custom section will be added in the PDF",
          details: "This is the exact information shown in the invoice",
          displayName: "Section name displayed in the invoice"
        }
      }
    )

    result_data = result["data"]["createInvoiceCustomSection"]

    expect(result_data["id"]).to be_present
    expect(result_data["name"]).to eq("First Invoice Custom Section")
    expect(result_data["displayName"]).to eq("Section name displayed in the invoice")
    expect(result_data["code"]).to eq("section_code")
    expect(result_data["description"]).to eq("this invoice custom section will be added in the PDF")
    expect(result_data["details"]).to eq("This is the exact information shown in the invoice")
  end

  context "when fail to create invoice_custom_section" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            code: nil,
            name: "First Invoice Custom Section",
            description: "this invoice custom section will be added in the PDF",
            details: "This is the exact information shown in the invoice",
            displayName: "Section name displayed in the invoice"
          }
        }
      )

      expect(result["errors"]).to be_present
      expect(result["errors"].first["message"]).to include("invalid value for code")
    end
  end
end
