# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Customers::UpdateInvoiceGracePeriod, :premium do
  let(:required_permission) { "customers:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }

  let(:mutation) do
    <<~GQL
      mutation($input: UpdateCustomerInvoiceGracePeriodInput!) {
        updateCustomerInvoiceGracePeriod(input: $input) {
          id,
          name,
          externalId,
          invoiceGracePeriod
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", %w[customers:update]

  it "updates a customer" do
    result = execute_query(
      query: mutation,
      input: {
        id: customer.id,
        invoiceGracePeriod: 12
      }
    )

    result_data = result["data"]["updateCustomerInvoiceGracePeriod"]

    expect(result_data["id"]).to be_present
    expect(result_data["invoiceGracePeriod"]).to eq(12)
  end
end
