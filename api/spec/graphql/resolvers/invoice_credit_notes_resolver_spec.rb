# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::InvoiceCreditNotesResolver do
  let(:required_permission) { "credit_notes:view" }
  let(:query) do
    <<~GQL
      query($invoiceId: ID!) {
        invoiceCreditNotes(invoiceId: $invoiceId, limit: 5) {
          collection { id }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:subscription) { create(:subscription, customer:, organization:) }
  let(:credit_note) { create(:credit_note, organization:, customer:, invoice:) }

  before do
    subscription
    credit_note
    create(:credit_note, :draft, organization:, customer:, invoice:)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "credit_notes:view"

  it "returns a list of finalized credit_notes for an invoice" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {
        invoiceId: invoice.id
      }
    )

    credit_notes_response = result["data"]["invoiceCreditNotes"]

    expect(credit_notes_response["collection"].count).to eq(1)
    expect(credit_notes_response["collection"].first["id"]).to eq(credit_note.id)

    expect(credit_notes_response["metadata"]["currentPage"]).to eq(1)
    expect(credit_notes_response["metadata"]["totalCount"]).to eq(1)
  end

  context "when invoice does not exists" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          invoiceId: "123456"
        }
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
