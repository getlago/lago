# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::TaxResolver do
  let(:query) do
    <<~GQL
      query($taxId: ID!) {
        tax(id: $taxId) {
          id code description name rate customersCount
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:tax) { create(:tax, organization:) }

  before do
    tax
  end

  it "returns a single tax" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:,
      variables: {taxId: tax.id}
    )

    expect(result["data"]["tax"]).to include(
      "id" => tax.id,
      "code" => tax.code,
      "description" => tax.description,
      "name" => tax.name,
      "rate" => tax.rate,
      "customersCount" => 0
    )
  end

  context "without current organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        query:,
        variables: {taxId: tax.id}
      )

      expect_graphql_error(result:, message: "Missing organization id")
    end
  end

  context "when tax is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {taxId: "unknown"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
