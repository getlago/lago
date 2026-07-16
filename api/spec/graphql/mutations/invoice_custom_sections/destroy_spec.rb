# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::InvoiceCustomSections::Destroy do
  subject(:result) do
    execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query:,
      variables: {input: {id: invoice_custom_section.id}}
    )
  end

  let(:query) do
    <<-GQL
      mutation($input: DestroyInvoiceCustomSectionInput!) {
        destroyInvoiceCustomSection(input: $input) { id }
      }
    GQL
  end

  let(:required_permission) { "invoice_custom_sections:delete" }
  let(:membership) { create(:membership) }
  let(:invoice_custom_section) { create(:invoice_custom_section, organization: membership.organization) }

  before { invoice_custom_section }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoice_custom_sections:delete"

  context "when invoice custom section with such ID exists in the current organization" do
    it "destroys the invoice custom section" do
      expect { result }.to change(InvoiceCustomSection, :count).from(1).to(0)
    end
  end

  context "when invoice_custom_section with such ID does not exist in the current organization" do
    let(:invoice_custom_section) { create(:invoice_custom_section) }

    it "does not delete the invoice_custom_section" do
      expect { result }.not_to change(InvoiceCustomSection, :count)
    end

    it "returns an error" do
      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
