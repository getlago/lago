# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::BillingEntityResolver do
  subject(:graphql_request) do
    execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query:,
      variables: {billingEntityCode: billing_entity.code}
    )
  end

  let(:required_permission) { "billing_entities:view" }
  let(:query) do
    <<~GQL
      query($billingEntityCode: String!) {
        billingEntity(code: $billingEntityCode) {
          id
          name
          legalName
          legalNumber
          taxIdentificationNumber
          email
          addressLine1
          addressLine2
          zipcode
          state
          country
          city
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:billing_entity) { create(:billing_entity, organization:) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "billing_entities:view"

  it "returns a single billing entity" do
    entity_response = graphql_request["data"]["billingEntity"]

    expect(entity_response["id"]).to eq(billing_entity.id)
    expect(entity_response["name"]).to eq(billing_entity.name)
    expect(entity_response["legalName"]).to eq(billing_entity.legal_name)
    expect(entity_response["legalNumber"]).to eq(billing_entity.legal_number)
    expect(entity_response["taxIdentificationNumber"]).to eq(billing_entity.tax_identification_number)
    expect(entity_response["email"]).to eq(billing_entity.email)
    expect(entity_response["addressLine1"]).to eq(billing_entity.address_line1)
    expect(entity_response["addressLine2"]).to eq(billing_entity.address_line2)
    expect(entity_response["zipcode"]).to eq(billing_entity.zipcode)
    expect(entity_response["state"]).to eq(billing_entity.state)
    expect(entity_response["country"]).to eq(billing_entity.country)
    expect(entity_response["city"]).to eq(billing_entity.city)
  end

  context "when billing_entity is archived" do
    before do
      billing_entity.update(archived_at: Time.current)
    end

    it "returns the billing_entity" do
      entity_response = graphql_request["data"]["billingEntity"]

      expect(entity_response["id"]).to eq(billing_entity.id)
      expect(entity_response["name"]).to eq(billing_entity.name)
      expect(entity_response["legalName"]).to eq(billing_entity.legal_name)
      expect(entity_response["legalNumber"]).to eq(billing_entity.legal_number)
    end
  end

  context "when billing entity is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {billingEntityCode: "foo"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end

  context "when billing_entity is deleted" do
    it "returns an error" do
      billing_entity.discard
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {billingEntityCode: billing_entity.code}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
