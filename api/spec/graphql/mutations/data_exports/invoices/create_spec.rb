# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::DataExports::Invoices::Create do
  include_context "with mocked security logger"

  let(:required_permission) { "invoices:export" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:mutation) do
    <<-GQL
      mutation($input: CreateDataExportsInvoicesInput!) {
        createInvoicesDataExport(input: $input) {
          id,
          status,
       }
      }
    GQL
  end

  before { membership }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:export"

  context "with valid input" do
    let!(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            format: "csv",
            resourceType: "invoices",
            filters: {
              amountFrom: 0,
              amountTo: 10000,
              currency: "USD",
              customerExternalId: "abc123",
              invoiceType: ["one_off"],
              issuingDateFrom: "2024-05-23",
              issuingDateTo: "2024-07-01",
              paymentDisputeLost: false,
              paymentOverdue: true,
              paymentStatus: ["pending"],
              searchTerm: "service ABC",
              status: ["finalized"]
            }
          }
        }
      )
    end

    it "creates data export" do
      result_data = result["data"]["createInvoicesDataExport"]

      expect(result_data).to include(
        "id" => String,
        "status" => "pending"
      )
    end

    it_behaves_like "produces a security log", "export.created"
  end
end
