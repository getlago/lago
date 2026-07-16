# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Wallets::Create, :premium do
  let(:required_permission) { "wallets:create" }
  let(:membership) { create(:membership) }
  let(:customer) { create(:customer, organization: membership.organization, currency: "EUR") }
  let(:billable_metric) { create(:billable_metric, organization: membership.organization) }
  let(:expiration_at) { Time.zone.now + 1.year }

  let(:mutation) do
    <<-GQL
      mutation($input: CreateCustomerWalletInput!) {
        createCustomerWallet(input: $input) {
          id
          code
          name
          priority
          rateAmount
          status
          currency
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
            expirationAt
            ignorePaidTopUpLimits
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

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "wallets:create"

  it "creates a wallet" do
    result = execute_graphql(
      current_user: membership.user,
      current_organization: membership.organization,
      permissions: required_permission,
      query: mutation,
      variables: {
        input: {
          customerId: customer.id,
          name: "First Wallet",
          priority: 9,
          rateAmount: "1",
          paidCredits: "10.00",
          grantedCredits: "0.00",
          expirationAt: expiration_at.iso8601,
          currency: "EUR",
          invoiceRequiresSuccessfulPayment: true,
          paidTopUpMinAmountCents: 1_00,
          paidTopUpMaxAmountCents: 100_00,
          transactionName: "Initial Credits Purchase",
          recurringTransactionRules: [
            {
              method: "target",
              trigger: "interval",
              interval: "monthly",
              targetOngoingBalance: "0.0",
              invoiceRequiresSuccessfulPayment: true,
              expirationAt: expiration_at.iso8601,
              ignorePaidTopUpLimits: true,
              grantsTargetTopUp: true,
              transactionMetadata: [
                {key: "example_key", value: "example_value"},
                {key: "another_key", value: "another_value"}
              ],
              transactionName: "Monthly AI Credits Top-up"
            }
          ],
          appliesTo: {
            feeTypes: %w[subscription],
            billableMetricIds: [billable_metric.id]
          }
        }
      }
    )

    result_data = result["data"]["createCustomerWallet"]

    expect(result_data["id"]).to be_present
    expect(result_data["code"]).to eq("first_wallet")
    expect(result_data["name"]).to eq("First Wallet")
    expect(result_data["priority"]).to eq(9)
    expect(result_data["invoiceRequiresSuccessfulPayment"]).to eq(true)
    expect(result_data["expirationAt"]).to eq(expiration_at.iso8601)
    expect(result_data["paidTopUpMinAmountCents"]).to eq("100")
    expect(result_data["paidTopUpMaxAmountCents"]).to eq("10000")
    expect(result_data["recurringTransactionRules"].count).to eq(1)
    expect(result_data["recurringTransactionRules"][0]["lagoId"]).to be_present
    expect(result_data["recurringTransactionRules"][0]["method"]).to eq("target")
    expect(result_data["recurringTransactionRules"][0]["trigger"]).to eq("interval")
    expect(result_data["recurringTransactionRules"][0]["interval"]).to eq("monthly")
    expect(result_data["recurringTransactionRules"][0]["paidCredits"]).to eq("0.0")
    expect(result_data["recurringTransactionRules"][0]["grantedCredits"]).to eq("0.0")
    expect(result_data["recurringTransactionRules"][0]["invoiceRequiresSuccessfulPayment"]).to eq(true)
    expect(result_data["recurringTransactionRules"][0]["ignorePaidTopUpLimits"]).to eq(true)
    expect(result_data["recurringTransactionRules"][0]["grantsTargetTopUp"]).to eq(true)
    expect(result_data["recurringTransactionRules"][0]["transactionMetadata"]).to contain_exactly(
      {"key" => "example_key", "value" => "example_value"},
      {"key" => "another_key", "value" => "another_value"}
    )
    expect(result_data["recurringTransactionRules"][0]["transactionName"]).to eq("Monthly AI Credits Top-up")
    expect(result_data["appliesTo"]["feeTypes"]).to eq(["subscription"])
    expect(result_data["appliesTo"]["billableMetrics"].first["id"]).to eq(billable_metric.id)

    expect(WalletTransactions::CreateJob).to have_been_enqueued.with(
      organization_id: membership.organization.id,
      params: {
        wallet_id: Regex::UUID,
        paid_credits: "10.00",
        granted_credits: "0.00",
        source: :manual,
        metadata: nil,
        priority: nil,
        name: "Initial Credits Purchase",
        ignore_paid_top_up_limits: nil
      }
    )
    expect(SendWebhookJob).to have_been_enqueued.with("wallet.created", Wallet)
  end

  context "when grants_target_top_up is omitted on a target rule" do
    it "defaults grants_target_top_up to false" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            name: "Default Wallet",
            priority: 9,
            rateAmount: "1",
            paidCredits: "0.00",
            grantedCredits: "0.00",
            expirationAt: expiration_at.iso8601,
            currency: "EUR",
            recurringTransactionRules: [
              {
                method: "target",
                trigger: "interval",
                interval: "monthly",
                targetOngoingBalance: "0.0"
              }
            ]
          }
        }
      )

      result_data = result["data"]["createCustomerWallet"]

      expect(result_data["recurringTransactionRules"].count).to eq(1)
      expect(result_data["recurringTransactionRules"][0]).to include("grantsTargetTopUp" => false)
    end
  end

  context "when name is not present" do
    it "creates a wallet with default code" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            name: nil,
            priority: 11,
            rateAmount: "1",
            paidCredits: "0.00",
            grantedCredits: "0.00",
            expirationAt: (Time.zone.now + 1.year).iso8601,
            currency: "EUR"
          }
        }
      )

      result_data = result["data"]["createCustomerWallet"]

      expect(result_data["id"]).to be_present
      expect(result_data["name"]).to be_nil
      expect(result_data["code"]).to eq("default")
    end
  end

  context "when code is provided" do
    it "creates a wallet with the provided code" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            name: "My Wallet",
            code: "custom_code",
            priority: 9,
            rateAmount: "1",
            paidCredits: "0.00",
            grantedCredits: "0.00",
            expirationAt: expiration_at.iso8601,
            currency: "EUR"
          }
        }
      )

      result_data = result["data"]["createCustomerWallet"]

      expect(result_data["id"]).to be_present
      expect(result_data["code"]).to eq("custom_code")
      expect(result_data["name"]).to eq("My Wallet")
    end
  end

  context "when code is already taken for the customer" do
    before do
      create(:wallet, customer:, code: "existing_code")
    end

    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            name: "My Wallet",
            code: "existing_code",
            priority: 9,
            rateAmount: "1",
            paidCredits: "0.00",
            grantedCredits: "0.00",
            expirationAt: expiration_at.iso8601,
            currency: "EUR"
          }
        }
      )

      expect_unprocessable_entity(result, details: {code: ["value_already_exist"]})
    end
  end

  context "when transaction_name is not provided" do
    it "creates a wallet with null transaction_name" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            name: "Test Wallet",
            priority: 9,
            rateAmount: "1",
            paidCredits: "10.00",
            grantedCredits: "0.00",
            expirationAt: expiration_at.iso8601,
            currency: "EUR",
            recurringTransactionRules: [
              {
                method: "fixed",
                trigger: "interval",
                interval: "monthly",
                paidCredits: "10.0",
                grantedCredits: "5.0"
              }
            ]
          }
        }
      )

      result_data = result["data"]["createCustomerWallet"]

      expect(result_data["id"]).to be_present
      expect(result_data["recurringTransactionRules"].count).to eq(1)
      expect(result_data["recurringTransactionRules"][0]["transactionName"]).to be_nil

      expect(WalletTransactions::CreateJob).to have_been_enqueued.with(
        organization_id: membership.organization.id,
        params: {
          wallet_id: Regex::UUID,
          paid_credits: "10.00",
          granted_credits: "0.00",
          source: :manual,
          metadata: nil,
          priority: nil,
          name: nil,
          ignore_paid_top_up_limits: nil
        }
      )
    end
  end

  context "with metadata" do
    it "creates a wallet with metadata" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: membership.organization,
        permissions: required_permission,
        query: mutation,
        variables: {
          input: {
            customerId: customer.id,
            name: "Wallet with Metadata",
            priority: 9,
            rateAmount: "1",
            paidCredits: "0.00",
            grantedCredits: "0.00",
            expirationAt: expiration_at.iso8601,
            currency: "EUR",
            metadata: [
              {key: "env", value: "production"},
              {key: "team", value: "engineering"}
            ]
          }
        }
      )

      result_data = result["data"]["createCustomerWallet"]

      expect(result_data["id"]).to be_present
      expect(result_data["name"]).to eq("Wallet with Metadata")
      expect(result_data["metadata"]).to contain_exactly(
        {"key" => "env", "value" => "production"},
        {"key" => "team", "value" => "engineering"}
      )
    end
  end
end
