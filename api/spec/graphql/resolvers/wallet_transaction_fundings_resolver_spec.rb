# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::WalletTransactionFundingsResolver do
  let(:query) do
    <<~GQL
      query($walletTransactionId: ID!, $page: Int, $limit: Int) {
        walletTransactionFundings(walletTransactionId: $walletTransactionId, page: $page, limit: $limit) {
          collection {
            id
            amountCents
            creditAmount
            createdAt
            walletTransaction { id }
          }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:, traceable: true) }
  let(:inbound_transaction) do
    create(:wallet_transaction,
      wallet:,
      organization:,
      transaction_type: :inbound,
      remaining_amount_cents: 10000)
  end
  let(:outbound_transaction) do
    create(:wallet_transaction, wallet:, organization:, transaction_type: :outbound)
  end
  let!(:consumption) do
    create(:wallet_transaction_consumption,
      organization:,
      inbound_wallet_transaction: inbound_transaction,
      outbound_wallet_transaction: outbound_transaction,
      consumed_amount_cents: 500)
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"

  it "returns a list of fundings for an outbound transaction" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: organization,
      query:,
      variables: {walletTransactionId: outbound_transaction.id, limit: 5}
    )

    fundings_response = result["data"]["walletTransactionFundings"]

    expect(fundings_response["collection"].count).to eq(1)
    expect(fundings_response["collection"].first["id"]).to eq(consumption.id)
    expect(fundings_response["collection"].first["amountCents"]).to eq("500")
    expect(fundings_response["collection"].first["walletTransaction"]["id"]).to eq(inbound_transaction.id)
    expect(fundings_response["metadata"]["currentPage"]).to eq(1)
    expect(fundings_response["metadata"]["totalCount"]).to eq(1)
  end

  context "with pagination" do
    let(:inbounds) { create_list(:wallet_transaction, 3, wallet:, organization:, transaction_type: :inbound, remaining_amount_cents: 10000) }

    before do
      inbounds.each do |inbound|
        create(:wallet_transaction_consumption,
          organization:,
          inbound_wallet_transaction: inbound,
          outbound_wallet_transaction: outbound_transaction,
          consumed_amount_cents: 100)
      end
    end

    it "returns paginated results" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {walletTransactionId: outbound_transaction.id, page: 1, limit: 2}
      )

      fundings_response = result["data"]["walletTransactionFundings"]

      expect(fundings_response["collection"].count).to eq(2)
      expect(fundings_response["metadata"]["currentPage"]).to eq(1)
      expect(fundings_response["metadata"]["totalCount"]).to eq(4)
    end

    it "returns second page of results" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {walletTransactionId: outbound_transaction.id, page: 2, limit: 2}
      )

      fundings_response = result["data"]["walletTransactionFundings"]

      expect(fundings_response["collection"].count).to eq(2)
      expect(fundings_response["metadata"]["currentPage"]).to eq(2)
      expect(fundings_response["metadata"]["totalCount"]).to eq(4)
    end
  end

  context "when transaction is inbound" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {walletTransactionId: inbound_transaction.id}
      )

      expect_graphql_error(result:, message: "Unprocessable Entity")
    end
  end

  context "when wallet is not traceable" do
    let(:wallet) { create(:wallet, customer:, traceable: false) }

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {walletTransactionId: outbound_transaction.id}
      )

      expect_graphql_error(result:, message: "Unprocessable Entity")
    end
  end

  context "when transaction does not exist" do
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {walletTransactionId: "non-existent-id"}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end

  context "when transaction belongs to another organization" do
    let(:other_organization) { create(:organization) }
    let(:other_customer) { create(:customer, organization: other_organization) }
    let(:other_wallet) { create(:wallet, customer: other_customer, traceable: true) }
    let(:other_transaction) do
      create(:wallet_transaction,
        wallet: other_wallet,
        organization: other_organization,
        transaction_type: :outbound)
    end

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        query:,
        variables: {walletTransactionId: other_transaction.id}
      )

      expect_graphql_error(result:, message: "Resource not found")
    end
  end
end
