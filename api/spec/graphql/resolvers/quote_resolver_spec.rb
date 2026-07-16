# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::QuoteResolver do
  let(:required_permission) { "quotes:view" }
  let(:query) do
    <<-GQL
      query($quoteId: ID!) {
        quote(id: $quoteId) {
          id
          customer { id name }
          organization { id name }
          subscription { id }
          number
          orderType
          images
          currentVersion { id version status billingItems content currency startDate endDate }
          versions { id version status }
          createdAt
          updatedAt
          owners { id email }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "quotes:view"

  context "when the quote exists" do
    let(:quote) { create(:quote, :with_version, version_trait: :voided, organization:, customer:) }
    let(:current_version) { create(:quote_version, organization:, quote:) }

    before do
      quote
      current_version
    end

    it "returns a single quote" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          quoteId: quote.id
        }
      )

      response = result.dig("data", "quote")

      expect(response.dig("id")).to eq(quote.id)
      expect(response.dig("organization", "id")).to eq(organization.id)
      expect(response.dig("organization", "name")).to eq(organization.name)
      expect(response.dig("subscription", "id")).to eq(quote.subscription_id)
      expect(response.dig("customer", "id")).to eq(customer.id)
      expect(response.dig("customer", "name")).to eq(customer.name)
      expect(response.dig("number")).to eq(quote.number)
      expect(response.dig("orderType")).to eq(quote.order_type)
      expect(response.dig("createdAt")).to eq(quote.created_at.iso8601)
      expect(response.dig("updatedAt")).to eq(quote.updated_at.iso8601)
      expect(response.dig("owners")).to eq([])
      expect(response.dig("images")).to eq({})

      expect(response.dig("currentVersion", "id")).to eq(quote.current_version.id)
      expect(response.dig("currentVersion", "billingItems")).to eq(quote.current_version.billing_items)
      expect(response.dig("currentVersion", "content")).to eq(quote.current_version.content)
      expect(response.dig("currentVersion", "status")).to eq(quote.current_version.status)
      expect(response.dig("currentVersion", "version")).to eq(quote.current_version.version)
      expect(response.dig("currentVersion", "currency")).to eq(quote.current_version.currency)
      expect(response.dig("currentVersion", "startDate")).to eq(quote.current_version.start_date&.iso8601)
      expect(response.dig("currentVersion", "endDate")).to eq(quote.current_version.end_date&.iso8601)
      expect(response.dig("versions")).to match_array(
        [
          {
            "id" => quote.versions[0].id,
            "version" => quote.versions[0].version,
            "status" => quote.versions[0].status
          },
          {
            "id" => quote.versions[1].id,
            "version" => quote.versions[1].version,
            "status" => quote.versions[1].status
          }
        ]
      )
    end
  end

  context "when the quote has images" do
    let(:quote) { create(:quote, organization:, customer:) }
    let(:query) do
      <<-GQL
        query($quoteId: ID!) {
          quote(id: $quoteId) {
            id
            images
          }
        }
      GQL
    end

    before do
      quote.images.attach(
        io: File.open(Rails.root.join("spec/factories/images/logo.png")),
        content_type: "image/png",
        filename: "logo.png"
      )
    end

    it "returns a map of blob id to a fresh url" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {quoteId: quote.id}
      )

      images = result.dig("data", "quote", "images")
      blob_id = quote.images.first.blob.id

      expect(images.keys).to eq([blob_id])
      expect(images[blob_id]).to include("/rails/active_storage/blobs")
    end
  end

  context "when the quote is not found" do
    it "returns a not found error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {
          quoteId: "00000000-0000-0000-0000-000000000000"
        }
      )

      expect_not_found(result)
    end
  end

  context "with N+1 query detection", :with_bullet, bullet: {n_plus_one_query: true, unused_eager_loading: false} do
    let(:other_user) { create(:user) }
    let(:subscription) { create(:subscription, organization:, customer:) }
    let(:quote) { create(:quote, organization:, customer:, subscription:, order_type: :subscription_amendment) }

    let(:query) do
      <<~GQL
        query($quoteId: ID!) {
          quote(id: $quoteId) {
            id
            customer { id }
            organization { id }
            subscription { id }
            owners { id }
            versions { id quote { id } organization { id } }
            currentVersion { id quote { id } organization { id } }
          }
        }
      GQL
    end

    before do
      quote
      QuoteOwner.create!(organization:, quote:, user: membership.user)
      QuoteOwner.create!(organization:, quote:, user: other_user)
      create(:quote_version, :voided, organization:, quote:)
      create(:quote_version, organization:, quote:)
    end

    it "does not trigger N+1 queries" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {quoteId: quote.id}
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "quote", "id")).to eq(quote.id)
    end
  end
end
