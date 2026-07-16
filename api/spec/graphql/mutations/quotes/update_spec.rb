# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Quotes::Update do
  let(:required_permission) { "quotes:update" }
  let(:membership) { create(:membership) }
  let(:quote) { create(:quote, :with_version, organization: membership.organization) }

  let(:input) do
    {
      id: quote.id,
      owners: [membership.user.id]
    }
  end

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateQuoteInput!) {
        updateQuote(input: $input) {
          id,
          organization { id },
          owners { id email }
        }
      }
    GQL
  end

  before do
    membership.organization.enable_feature_flag!(:order_forms)
    quote
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "quotes:update"

  context "with valid input", :premium do
    let!(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )
    end

    it "updates a quote" do
      expect(result["data"]["updateQuote"]).to include(
        "id" => quote.id,
        "organization" => {"id" => membership.organization.id},
        "owners" => [
          {
            "id" => membership.user.id,
            "email" => membership.user.email
          }
        ]
      )
    end
  end

  context "when quote is not found", :premium do
    let(:input) do
      {
        id: "00000000-0000-0000-0000-000000000000",
        owners: [membership.user.id]
      }
    end

    it "returns a not found error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect_not_found(result)
    end
  end
end
