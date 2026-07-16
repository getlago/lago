# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::InvoiceCustomSectionResolver do
  let(:query) do
    <<~GQL
      query($invoiceCustomSectionId: ID!) {
        invoiceCustomSection(id: $invoiceCustomSectionId) {
          id code name description details displayName
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:invoice_custom_section) { create(:invoice_custom_section, organization:) }

  before { invoice_custom_section }

  it "returns a single invoice_custom_section" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:,
      variables: {invoiceCustomSectionId: invoice_custom_section.id}
    )

    expect(result["data"]["invoiceCustomSection"]).to include(
      "id" => invoice_custom_section.id,
      "code" => invoice_custom_section.code,
      "name" => invoice_custom_section.name,
      "description" => invoice_custom_section.description,
      "details" => invoice_custom_section.details,
      "displayName" => invoice_custom_section.display_name
    )
  end

  context "without current organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        query:,
        variables: {invoiceCustomSectionId: invoice_custom_section.id}
      )

      expect_graphql_error(result:, message: "Missing organization id")
    end
  end

  context "when invoice_custom_section is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {invoiceCustomSectionId: "unknown"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
