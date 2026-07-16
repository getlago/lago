# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::PaymentRequests::Create do
  let(:required_permission) { "payments:create" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:invoice1) { create(:invoice, organization:) }
  let(:invoice2) { create(:invoice, organization:) }

  let(:input) do
    {
      email: "john.doe@example.com",
      externalCustomerId: customer.external_id,
      lagoInvoiceIds: [invoice1.id, invoice2.id]
    }
  end

  let(:mutation) do
    <<-GQL
      mutation($input: PaymentRequestCreateInput!) {
        createPaymentRequest(input: $input) {
          id
          email
          customer { id }
          invoices { id }
        }
      }
    GQL
  end

  it "creates a payment request" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {input:}
    )

    expect(result["data"]).to include(
      "createPaymentRequest" => nil
    )
  end
end
