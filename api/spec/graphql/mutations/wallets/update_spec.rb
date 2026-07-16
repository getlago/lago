# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Wallets::Update, :premium do
  let(:required_permission) { "wallets:update" }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:customer) { create(:customer, organization:) }
  let(:billable_metric) { create(:billable_metric, organization: membership.organization) }
  let(:subscription) { create(:subscription, customer:) }
  let(:wallet) { create(:wallet, customer:) }
  let(:expiration_at) { (Time.zone.now + 1.year) }
  let(:recurring_transaction_rule) { create(:recurring_transaction_rule, wallet:) }

  let(:mutation) do
    <<-GQL
      mutation($input: UpdateCustomerWalletInput!) {
        updateCustomerWallet(input: $input) {
          id
          code
          name
          priority
          status
          expirationAt
          invoiceRequiresSuccessfulPayment
          paidTopUpMinAmountCents
          paidTopUpMaxAmountCents
          metadata {
            key
            value
          }
          recurringTransactionRules {
            lagoId
            method
            trigger
            interval
            thresholdCredits
            paidCredits
            grantedCredits
            grantsTargetTopUp
            targetOngoingBalance
            invoiceRequiresSuccessfulPayment
            ignorePaidTopUpLimits
            expirationAt
            transactionMetadata {
              key
              value
            }
            transactionName
          }
          appliesTo {
            feeTypes
            billableMetrics {
              id
            }
          }
        }
      }
    GQL
  end

  before do
    subscription
    recurring_transaction_rule
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "wallets:update"

  it "updates a wallet" do
    result = execute_graphql(
      current_organization: organization,
      current_user: membership.user,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          id: wallet.id,
          name: "New name",
          priority: 22,
          expirationAt: expiration_at.iso8601,
          invoiceRequiresSuccessfulPayment: true,
          paidTopUpMinAmountCents: 1_00,
          paidTopUpMaxAmountCents: 100_00,
          recurringTransactionRules: [
            {
              lagoId: recurring_transaction_rule.id,
              method: "target",
              trigger: "interval",
              interval: "weekly",
              paidCredits: "22.2",
              grantedCredits: "22.2",
              targetOngoingBalance: "300",
              invoiceRequiresSuccessfulPayment: true,
              ignorePaidTopUpLimits: true,
              grantsTargetTopUp: false,
              expirationAt: expiration_at.iso8601,
              transactionMetadata: [
                {key: "example_key", value: "example_value"},
                {key: "another_key", value: "another_value"}
              ],
              transactionName: "Updated Credits Transaction"
            }
          ],
          appliesTo: {
            feeTypes: %w[subscription],
            billableMetricIds: [billable_metric.id]
          }
        }
      }
    )

    result_data = result["data"]["updateCustomerWallet"]

    expect(result_data).to include(
      "id" => wallet.id,
      "code" => wallet.code,
      "name" => "New name",
      "priority" => 22,
      "status" => "active",
      "invoiceRequiresSuccessfulPayment" => true,
      "expirationAt" => expiration_at.iso8601,
      "paidTopUpMinAmountCents" => "100",
      "paidTopUpMaxAmountCents" => "10000"
    )

    expect(result_data["recurringTransactionRules"].count).to eq(1)
    expect(result_data["recurringTransactionRules"][0]["transactionMetadata"]).to contain_exactly(
      {"key" => "example_key", "value" => "example_value"},
      {"key" => "another_key", "value" => "another_value"}
    )
    expect(result_data["recurringTransactionRules"][0]["transactionName"]).to eq("Updated Credits Transaction")
    expect(result_data["recurringTransactionRules"][0]).to include(
      "lagoId" => recurring_transaction_rule.id,
      "method" => "target",
      "trigger" => "interval",
      "interval" => "weekly",
      "paidCredits" => "22.2",
      "grantedCredits" => "22.2",
      "targetOngoingBalance" => "300.0",
      "invoiceRequiresSuccessfulPayment" => true,
      "ignorePaidTopUpLimits" => true,
      "grantsTargetTopUp" => false
    )
    expect(result_data["appliesTo"]["feeTypes"]).to eq(["subscription"])
    expect(result_data["appliesTo"]["billableMetrics"].first["id"]).to eq(billable_metric.id)

    expect(SendWebhookJob).to have_been_enqueued.with("wallet.updated", Wallet)
  end

  context "with metadata" do
    it "updates a wallet with metadata" do
      result = execute_graphql(
        current_organization: organization,
        current_user: membership.user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: wallet.id,
            name: "Wallet with Metadata",
            priority: 22,
            metadata: [
              {key: "env", value: "staging"},
              {key: "region", value: "us-east"}
            ]
          }
        }
      )

      result_data = result["data"]["updateCustomerWallet"]

      expect(result_data["id"]).to eq(wallet.id)
      expect(result_data["name"]).to eq("Wallet with Metadata")
      expect(result_data["metadata"]).to contain_exactly(
        {"key" => "env", "value" => "staging"},
        {"key" => "region", "value" => "us-east"}
      )
    end
  end

  context "when updating code" do
    it "updates a wallet with the new code" do
      result = execute_graphql(
        current_organization: organization,
        current_user: membership.user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: wallet.id,
            code: "updated_code",
            priority: 22
          }
        }
      )

      result_data = result["data"]["updateCustomerWallet"]

      expect(result_data["id"]).to eq(wallet.id)
      expect(result_data["code"]).to eq("updated_code")
    end
  end

  context "when updating code to a value already taken for the customer" do
    before do
      create(:wallet, customer:, code: "existing_code")
    end

    it "returns an error" do
      result = execute_graphql(
        current_organization: organization,
        current_user: membership.user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: wallet.id,
            code: "existing_code",
            priority: 22
          }
        }
      )

      expect_unprocessable_entity(result, details: {code: ["value_already_exist"]})
    end
  end

  context "when updating billing_entity_id with multi_entity_billing enabled" do
    let(:billing_entity) { create(:billing_entity, organization:) }

    before do
      organization.update!(feature_flags: ["multi_entity_billing"])
    end

    it "updates the wallet's billing entity" do
      result = execute_graphql(
        current_organization: organization,
        current_user: membership.user,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            id: wallet.id,
            billingEntityId: billing_entity.id,
            priority: 22
          }
        }
      )

      expect(result["data"]["updateCustomerWallet"]["id"]).to eq(wallet.id)
      expect(wallet.reload.billing_entity_id).to eq(billing_entity.id)
    end
  end
end
