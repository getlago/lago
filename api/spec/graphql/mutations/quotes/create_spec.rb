# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Quotes::Create do
  let(:required_permission) { "quotes:create" }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization: membership.organization) }
  let(:input) do
    {
      customerId: customer.id,
      orderType: "one_off",
      content: "Test content",
      billingItems: {}
    }
  end
  let(:mutation) do
    <<-GQL
      mutation($input: CreateQuoteInput!) {
        createQuote(input: $input) {
          id,
          customer { id },
          organization { id },
          number,
          orderType
          currentVersion { id version status content billingItems }
          versions { id version status content billingItems }
        }
      }
    GQL
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "quotes:create"

  context "with valid input", :premium do
    before { membership.organization.enable_feature_flag!(:order_forms) }

    let!(:result) do
      execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {input:}
      )
    end

    it "creates a quote" do
      quote = result["data"]["createQuote"]
      expect(quote).to include(
        "id" => String,
        "customer" => {"id" => customer.id},
        "organization" => {"id" => membership.organization.id},
        "number" => String,
        "orderType" => "one_off",
        "currentVersion" => {
          "id" => String,
          "status" => "draft",
          "version" => 1,
          "content" => "Test content",
          "billingItems" => {}
        }
      )
      expect(quote["versions"].size).to eq(1)
      expect(quote["currentVersion"]).to eq(quote["versions"].first)
    end
  end

  context "when customer is not found", :premium do
    before { membership.organization.enable_feature_flag!(:order_forms) }

    let(:input) do
      {
        customerId: "00000000-0000-0000-0000-000000000000",
        orderType: "one_off",
        content: "Test content",
        billingItems: {}
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

  context "when subscription is required but missing", :premium do
    before { membership.organization.enable_feature_flag!(:order_forms) }

    let(:input) do
      {
        customerId: customer.id,
        orderType: "subscription_amendment",
        content: "Test content",
        billingItems: {}
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
