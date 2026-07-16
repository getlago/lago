# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Invoices::LoseDispute do
  let(:required_permission) { "invoices:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, status: :finalized, customer:, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: LoseInvoiceDisputeInput!) {
        loseInvoiceDispute(input: $input) {
          id
          paymentDisputeLostAt
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "invoices:update"

  it "marks payment dispute lost to true" do
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

      result_data = result["data"]["loseInvoiceDispute"]

      expect(result_data["id"]).to be_present
      expect(result_data["paymentDisputeLostAt"]).to be_present
    end
  end
end
