# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::OrderForms::MarkAsSigned do
  let(:required_permission) { "order_forms:sign" }
  let(:organization) { create(:organization, feature_flags: ["order_forms"]) }
  let(:membership) { create(:membership, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:quote) { create(:quote, organization:, customer:) }
  let(:order_form) { create(:order_form, organization:, customer:, quote:) }

  let(:mutation) do
    <<~GQL
      mutation($input: MarkOrderFormAsSignedInput!) {
        markOrderFormAsSigned(input: $input) {
          id
          status
          signedAt
          signedDocumentUrl
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "order_forms:sign"

  it "marks the order form as signed", :premium do
    freeze_time do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: order_form.id}}
      )

      data = result["data"]["markOrderFormAsSigned"]

      expect(data["id"]).to eq(order_form.id)
      expect(data["status"]).to eq("signed")
      expect(data["signedDocumentUrl"]).to be_nil
    end
  end

  it "signs with a document and execution settings", :premium do
    signed_document = "data:application/pdf;base64,#{Base64.strict_encode64(File.read(Rails.root.join("spec/fixtures/blank.pdf")))}"

    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {input: {id: order_form.id, signedDocument: signed_document, executionMode: "execute_in_lago", executeAt: 1.month.from_now.iso8601}}
    )

    data = result["data"]["markOrderFormAsSigned"]

    expect(data["status"]).to eq("signed")
    expect(data["signedDocumentUrl"]).to be_present
  end

  it "returns an error when execute_at is set without execution_mode", :premium do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {input: {id: order_form.id, executeAt: 1.month.from_now.iso8601}}
    )

    expect_unprocessable_entity(result, details: {executionMode: ["value_is_mandatory"]})
  end

  it "returns an error when execute_at is in the past", :premium do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      permissions: required_permission,
      query: mutation,
      variables: {input: {id: order_form.id, executionMode: "execute_in_lago", executeAt: 1.day.ago.iso8601}}
    )

    expect_unprocessable_entity(result, details: {executeAt: ["invalid_date"]})
  end

  context "when order form is not signable", :premium do
    let(:order_form) { create(:order_form, :signed, organization:, customer:, quote:) }

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: order_form.id}}
      )

      expect_graphql_error(result:, message: "Unprocessable Entity", details: {status: ["not_signable"]})
    end
  end

  context "when order form is not found", :premium do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query: mutation,
        variables: {input: {id: SecureRandom.uuid}}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
