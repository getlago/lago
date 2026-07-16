# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::QuoteVersionResolver do
  let(:required_permission) { "quotes:view" }
  let(:query) do
    <<-GQL
      query($id: ID!) {
        quoteVersion(id: $id) {
          id
          version
          status
          content
          billingItems
          currency
          startDate
          endDate
          quote { id }
          organization { id }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:quote_version) do
    create(
      :quote_version,
      organization:,
      quote:,
      content: "Some content",
      billing_items: {"foo" => "bar"},
      currency: "EUR",
      start_date: Date.new(2024, 1, 1),
      end_date: Date.new(2024, 12, 31)
    )
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "quotes:view"

  context "when id is provided" do
    it "returns a single quote version" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {id: quote_version.id}
      )

      response = result.dig("data", "quoteVersion")

      expect(response.dig("id")).to eq(quote_version.id)
      expect(response.dig("version")).to eq(quote_version.version)
      expect(response.dig("status")).to eq(quote_version.status)
      expect(response.dig("content")).to eq("Some content")
      expect(response.dig("billingItems")).to eq({"foo" => "bar"})
      expect(response.dig("currency")).to eq("EUR")
      expect(response.dig("startDate")).to eq("2024-01-01")
      expect(response.dig("endDate")).to eq("2024-12-31")
      expect(response.dig("quote", "id")).to eq(quote.id)
      expect(response.dig("organization", "id")).to eq(organization.id)
    end
  end

  context "when the quote version is not found" do
    it "returns a not found error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {id: "00000000-0000-0000-0000-000000000000"}
      )

      expect_not_found(result)
    end
  end
end
