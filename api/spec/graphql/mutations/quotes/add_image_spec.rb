# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Quotes::AddImage do
  let(:required_permission) { "quotes:update" }
  let(:membership) { create(:membership) }
  let(:quote) { create(:quote, organization: membership.organization) }

  let(:png_bytes) { "\x89PNG\r\n\x1A\n".b }
  let(:image) { "data:image/png;base64,#{Base64.strict_encode64(png_bytes)}" }

  let(:input) do
    {
      id: quote.id,
      image:
    }
  end

  let(:mutation) do
    <<-GQL
      mutation($input: AddQuoteImageInput!) {
        addQuoteImage(input: $input) {
          id
          url
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

  describe "payload" do
    subject { described_class.payload_type }

    it do
      expect(subject).to have_field(:id).of_type("ID!")
      expect(subject).to have_field(:url).of_type("String!")
    end
  end

  context "with valid input", :premium do
    it "attaches the image to the quote and returns its URL" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect(result["data"]["addQuoteImage"]["url"]).to include("/rails/active_storage/blobs")
      expect(result["data"]["addQuoteImage"]["id"]).to eq(quote.reload.images.first.blob.id)
      expect(quote.reload.images.count).to eq(1)
    end
  end

  context "when quote is not found", :premium do
    let(:input) do
      {
        id: "00000000-0000-0000-0000-000000000000",
        image:
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

  context "when the image is malformed", :premium do
    let(:image) { "not-a-data-uri" }

    it "returns a validation error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect_unprocessable_entity(result)
    end
  end

  context "when license is not premium" do
    it "returns a forbidden error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect_forbidden_error(result)
    end
  end
end
