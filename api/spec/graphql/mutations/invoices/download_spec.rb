# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::Download do
  let(:required_permission) { "invoices:view" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: DownloadInvoiceInput!) {
        downloadInvoice(input: $input) {
          id
        }
      }
    GQL
  end

  before { stub_pdf_generation }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:view"

  it "generates the PDF for the given invoice" do
    freeze_time do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {id: invoice.id}
        }
      )

      result_data = result["data"]["downloadInvoice"]

      expect(result_data["id"]).to be_present
    end
  end
end
