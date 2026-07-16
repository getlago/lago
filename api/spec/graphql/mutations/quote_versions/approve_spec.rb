# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::QuoteVersions::Approve do
  let(:required_permission) { "quotes:approve" }
  let(:membership) { create(:membership) }
  let(:quote_version) { create(:quote_version, organization: membership.organization) }

  let(:input) do
    {
      id: quote_version.id
    }
  end

  let(:mutation) do
    <<-GQL
      mutation($input: ApproveQuoteVersionInput!) {
        approveQuoteVersion(input: $input) {
          id,
          organization { id },
          version,
          status,
          approvedAt
        }
      }
    GQL
  end

  before do
    membership.organization.enable_feature_flag!(:order_forms)
    quote_version
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "quotes:approve"

  context "with valid input", :premium do
    it "approves a quote version" do
      freeze_time do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: membership.organization,
          permissions: required_permission,
          query: mutation,
          variables: {input:}
        )

        expect(result["data"]["approveQuoteVersion"]).to include(
          "id" => quote_version.id,
          "organization" => {"id" => membership.organization.id},
          "version" => quote_version.version,
          "status" => "approved",
          "approvedAt" => Time.current.iso8601
        )
      end
    end
  end

  context "with an expiresAt in the future", :premium do
    let(:expires_at) { 1.month.from_now.iso8601 }
    let(:input) { {id: quote_version.id, expiresAt: expires_at} }

    it "sets expires_at on the created order form" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect(result["data"]["approveQuoteVersion"]["status"]).to eq("approved")
      expect(quote_version.reload.order_form.expires_at).to be_within(1.second).of(Time.zone.parse(expires_at))
    end
  end

  context "with an expiresAt in the past", :premium do
    let(:input) { {id: quote_version.id, expiresAt: 1.day.ago.iso8601} }

    it "returns a validation error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect_graphql_error(result:, message: "Unprocessable Entity", details: {expiresAt: ["invalid_date"]})
      expect(quote_version.reload.status).to eq("draft")
    end
  end

  context "when quote version is not found", :premium do
    let(:input) { {id: "00000000-0000-0000-0000-000000000000"} }

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

  context "when quote version is not in draft state", :premium do
    let(:quote_version) { create(:quote_version, :voided, organization: membership.organization) }

    it "returns a validation error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )

      expect_graphql_error(result:, message: "Unprocessable Entity", details: {status: ["not_approvable"]})
    end
  end
end
