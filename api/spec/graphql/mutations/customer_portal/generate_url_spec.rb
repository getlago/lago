# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CustomerPortal::GenerateUrl do
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:user) { membership.user }
  let(:mutation) do
    <<-GQL
      mutation($input: GenerateCustomerPortalUrlInput!) {
        generateCustomerPortalUrl(input: $input) {
          url
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"

  context "when licence is premium", :premium do
    it "returns customer portal url" do
      result = execute_graphql(
        current_organization: organization,
        current_user: user,
        query: mutation,
        variables: {
          input: {id: customer.id}
        }
      )

      data = result["data"]["generateCustomerPortalUrl"]

      expect(data["url"]).to include("/customer-portal/")
    end
  end
end
