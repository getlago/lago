# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::OrderFormResolver do
  let(:required_permission) { "order_forms:view" }

  let(:query) do
    <<~GQL
      query($id: ID!) {
        orderForm(id: $id) {
          id
          number
          status
          signedDocumentUrl
          createdAt
          updatedAt
          quote {
            id
            number
            currentVersion { id }
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:order_form) { create(:order_form, organization:, customer:) }

  before { order_form }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "order_forms:view"

  it "returns a single order form" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {id: order_form.id}
    )

    data = result["data"]["orderForm"]

    expect(data["id"]).to eq(order_form.id)
    expect(data["number"]).to eq(order_form.number)
    expect(data["status"]).to eq("generated")
    expect(data["quote"]["id"]).to eq(order_form.quote.id)
    expect(data["quote"]["number"]).to eq(order_form.quote.number)
    expect(data["quote"]["currentVersion"]["id"]).to eq(order_form.quote_version.id)
    expect(data["signedDocumentUrl"]).to be_nil
  end

  context "when a signed document is attached" do
    let(:order_form) { create(:order_form, :with_signed_document, organization:, customer:) }

    it "exposes the signed document url" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {id: order_form.id}
      )

      expect(result["data"]["orderForm"]["signedDocumentUrl"]).to be_present
    end
  end

  context "when order form is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {id: SecureRandom.uuid}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
