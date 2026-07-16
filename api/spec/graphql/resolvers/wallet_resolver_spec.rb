# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::WalletResolver do
  let(:query) do
    <<~GQL
      query($id: ID!) {
        wallet(id: $id) {
          id name status creditsBalance
          metadata { key value }
          recurringTransactionRules {
            transactionName
          }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, :with_recurring_transaction_rules, customer:) }

  before { wallet }

  it "returns a wallet" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:,
      variables: {id: wallet.id}
    )

    wallet_response = result["data"]["wallet"]

    expect(wallet_response).to eq(
      {
        "creditsBalance" => 0.0,
        "id" => wallet.id,
        "name" => wallet.name,
        "metadata" => nil,
        "recurringTransactionRules" => [{"transactionName" => "Recurring Transaction Rule"}],
        "status" => "active"
      }
    )
  end

  context "when wallet has metadata" do
    let(:metadata) { create(:item_metadata, owner: wallet, value: {"key1" => "value_1", "key2" => "value_2"}) }

    before { metadata }

    it "returns wallet with metadata" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {id: wallet.id}
      )

      wallet_response = result["data"]["wallet"]

      expect(wallet_response).to include(
        "id" => wallet.id,
        "name" => wallet.name,
        "status" => "active",
        "metadata" => [
          {"key" => "key1", "value" => "value_1"},
          {"key" => "key2", "value" => "value_2"}
        ]
      )
    end
  end

  context "without current organization" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        query:,
        variables: {id: wallet.id}
      )

      expect_graphql_error(result:, message: "Missing organization id")
    end
  end

  context "when wallet is not found" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {id: "foo"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end

  context "with billing_entity_id field" do
    let(:query) do
      <<~GQL
        query($id: ID!) {
          wallet(id: $id) {
            id
            billingEntityId
          }
        }
      GQL
    end

    context "when the wallet is bound to a billing entity" do
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:wallet) { create(:wallet, customer:, billing_entity:) }

      it "returns the billing_entity_id" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          query:,
          variables: {id: wallet.id}
        )

        expect(result["data"]["wallet"]["billingEntityId"]).to eq(billing_entity.id)
      end
    end

    context "when the wallet has no billing entity (legacy row)" do
      let(:wallet) { create(:wallet, customer:, billing_entity: nil) }

      it "returns null" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          query:,
          variables: {id: wallet.id}
        )

        expect(result["data"]["wallet"]["billingEntityId"]).to be_nil
      end
    end
  end
end
