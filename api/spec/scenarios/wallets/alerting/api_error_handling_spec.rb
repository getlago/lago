# frozen_string_literal: true

require "rails_helper"

describe "Wallet Alert API Error Handling", :premium, transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }

  def create_test_wallet(code: "test-wallet")
    create_wallet({
      external_customer_id: customer.external_id,
      rate_amount: "1",
      name: "Test Wallet",
      code:,
      currency: "EUR",
      granted_credits: "100",
      invoice_requires_successful_payment: false
    }, as: :model)
  end

  describe "duplicate alert type for wallet" do
    it "returns error when creating duplicate alert type for same wallet" do
      wallet = create_test_wallet

      create_wallet_alert(customer.external_id, wallet.code, {
        alert_type: :wallet_balance_amount,
        code: :first_alert,
        thresholds: [{value: 50_00, code: :warn}]
      })

      # Creating a second wallet_balance_amount alert for the same wallet should fail
      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/#{customer.external_id}/wallets/#{wallet.code}/alerts",
          {alert: {
            alert_type: :wallet_balance_amount,
            code: :second_alert,
            thresholds: [{value: 30_00, code: :critical}]
          }}
        )
      end

      expect(response[:status]).to eq(422)
      expect(response[:code]).to eq("validation_errors")
      expect(response[:error_details]).to include("base" => ["alert_already_exists"])
    end
  end

  describe "invalid alert type for wallet" do
    it "returns error when using subscription alert type on wallet" do
      wallet = create_test_wallet

      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/#{customer.external_id}/wallets/#{wallet.code}/alerts",
          {alert: {
            alert_type: :current_usage_amount,
            code: :invalid_type,
            thresholds: [{value: 100_00, code: :warn}]
          }}
        )
      end

      expect(response[:status]).to eq(422)
      expect(response[:code]).to eq("validation_errors")
      expect(response[:error_details]).to include("alert_type" => ["invalid_type"])
    end
  end

  describe "missing required fields" do
    it "returns error when code is missing" do
      wallet = create_test_wallet

      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/#{customer.external_id}/wallets/#{wallet.code}/alerts",
          {alert: {
            alert_type: :wallet_balance_amount,
            thresholds: [{value: 50_00, code: :warn}]
          }}
        )
      end

      expect(response[:status]).to eq(422)
      expect(response[:code]).to eq("validation_errors")
      expect(response[:error_details]).to include("code" => ["value_is_mandatory"])
    end

    it "returns error when thresholds is missing" do
      wallet = create_test_wallet

      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/#{customer.external_id}/wallets/#{wallet.code}/alerts",
          {alert: {
            alert_type: :wallet_balance_amount,
            code: :missing_thresholds
          }}
        )
      end

      expect(response[:status]).to eq(422)
      expect(response[:code]).to eq("validation_errors")
      expect(response[:error_details]).to include("thresholds" => ["value_is_mandatory"])
    end

    it "returns error when alert_type is missing" do
      wallet = create_test_wallet

      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/#{customer.external_id}/wallets/#{wallet.code}/alerts",
          {alert: {
            code: :missing_type,
            thresholds: [{value: 50_00, code: :warn}]
          }}
        )
      end

      expect(response[:status]).to eq(422)
      expect(response[:code]).to eq("validation_errors")
      expect(response[:error_details]).to include("alert_type" => ["value_is_mandatory", "value_is_invalid"])
    end
  end

  describe "invalid thresholds" do
    it "returns error with duplicate threshold values" do
      wallet = create_test_wallet

      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/#{customer.external_id}/wallets/#{wallet.code}/alerts",
          {alert: {
            alert_type: :wallet_balance_amount,
            code: :duplicate_thresholds,
            thresholds: [
              {value: 100_00, code: :first},
              {value: 100_00, code: :duplicate},
              {value: 50_00, code: :third}
            ]
          }}
        )
      end

      expect(response[:status]).to eq(422)
      expect(response[:code]).to eq("validation_errors")
      expect(response[:error_details]).to include("thresholds" => ["duplicate_threshold_values"])
    end
  end

  describe "unsupported alert type" do
    it "returns error for unknown alert type" do
      wallet = create_test_wallet

      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/#{customer.external_id}/wallets/#{wallet.code}/alerts",
          {alert: {
            alert_type: :not_a_real_type,
            code: :unknown,
            thresholds: [{value: 50_00, code: :warn}]
          }}
        )
      end

      expect(response[:status]).to eq(422)
      expect(response[:code]).to eq("validation_errors")
      expect(response[:error_details]).to include("alert_type" => ["invalid_type"])
    end
  end

  describe "wallet not found" do
    it "returns not found error for non-existent wallet" do
      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/#{customer.external_id}/wallets/non-existent-wallet/alerts",
          {alert: {
            alert_type: :wallet_balance_amount,
            code: :test,
            thresholds: [{value: 50_00, code: :warn}]
          }}
        )
      end

      expect(response[:status]).to eq(404)
      expect(response[:code]).to eq("wallet_not_found")
    end
  end

  describe "customer not found" do
    it "returns not found error for non-existent customer" do
      response = api_call(raise_on_error: false) do
        post_with_token(
          organization,
          "/api/v1/customers/non-existent-customer/wallets/some-wallet/alerts",
          {alert: {
            alert_type: :wallet_balance_amount,
            code: :test,
            thresholds: [{value: 50_00, code: :warn}]
          }}
        )
      end

      expect(response[:status]).to eq(404)
      expect(response[:code]).to eq("customer_not_found")
    end
  end
end
