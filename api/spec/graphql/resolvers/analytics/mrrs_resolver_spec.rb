# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::Analytics::MrrsResolver do
  let(:required_permission) { "analytics:view" }
  let(:query) do
    <<~GQL
      query($currency: CurrencyEnum) {
        mrrs(currency: $currency) {
          collection {
            month
            amountCents
            currency
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "analytics:view"

  context "without premium feature" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect_graphql_error(
        result:,
        message: "unauthorized"
      )
    end
  end

  context "with premium feature", :premium do
    it "returns a list of mrrs" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      mrrs_response = result["data"]["mrrs"]
      month = DateTime.parse mrrs_response["collection"].first["month"]

      expect(month).to eq(DateTime.current.beginning_of_month)
      expect(mrrs_response["collection"].first["amountCents"]).to eq(nil)
      expect(mrrs_response["collection"].first["currency"]).to eq(nil)
    end
  end
end
