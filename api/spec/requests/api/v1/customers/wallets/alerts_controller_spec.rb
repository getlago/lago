# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Customers::Wallets::AlertsController do
  let(:organization) { create(:organization) }
  let(:customer_external_id) { customer.external_id }
  let(:wallet_code) { wallet.code }
  let(:customer) { create(:customer, organization:) }
  let(:wallet) { create(:wallet, customer:, organization:) }
  let(:code) { "my-wallet-alert" }
  let(:alert) { create(:wallet_balance_amount_alert, :processed, code:, wallet:, organization:) }
  let(:deleted_alert) { create(:wallet_balance_amount_alert, :processed, deleted_at: Time.current, wallet:, organization:, thresholds: []) }

  before do
    alert
    deleted_alert
  end

  RSpec.shared_examples "returns error if customer not found" do
    let(:customer_external_id) { "not-found-id" }

    it do
      subject
      expect(response).to be_not_found_error("customer")
    end
  end

  RSpec.shared_examples "returns error if wallet not found" do
    let(:wallet_code) { "not-found-code" }

    it do
      subject
      expect(response).to be_not_found_error("wallet")
    end
  end

  describe "GET /api/v1/customers/:external_id/wallets/:wallet_code/alerts" do
    subject { get_with_token(organization, "/api/v1/customers/#{customer_external_id}/wallets/#{wallet_code}/alerts") }

    it_behaves_like "requires API permission", "alert", "read"
    it_behaves_like "returns error if customer not found"
    it_behaves_like "returns error if wallet not found"

    context "when there are alerts" do
      it "retrieves a paginated list of alerts" do
        subject
        expect(json[:alerts].sole).to include({
          code:,
          lago_id: alert.id,
          alert_type: "wallet_balance_amount",
          previous_value: "800.0",
          name: "General Alert",
          created_at: be_present
        })
        expect(json[:meta]).to eq({
          current_page: 1,
          next_page: nil,
          prev_page: nil,
          total_pages: 1,
          total_count: 1
        })
      end
    end

    context "when there are no alerts" do
      let(:alert) { nil }

      it do
        subject
        expect(json[:alerts]).to be_empty
        expect(json[:meta][:total_count]).to eq 0
      end
    end
  end

  describe "POST /api/v1/customers/:external_id/wallets/:wallet_code/alerts" do
    subject { post_with_token(organization, "/api/v1/customers/#{customer_external_id}/wallets/#{wallet_code}/alerts", {alert: params}) }

    let(:alert) { nil }
    let(:params) do
      {
        code: "test",
        name: "New Wallet Alert",
        alert_type: "wallet_balance_amount",
        thresholds: [
          {code: :notice, value: 1000},
          {code: :warn, value: 5000},
          {code: :alert, value: 2000, recurring: true}
        ]
      }
    end

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if customer not found"
    it_behaves_like "returns error if wallet not found"

    it do
      subject

      expect(json[:alert]).to include({
        lago_id: be_present,
        code: "test",
        name: "New Wallet Alert",
        alert_type: "wallet_balance_amount",
        previous_value: "0.0",
        last_processed_at: be_nil,
        created_at: be_present
      })
    end

    context "when alert_type is wallet_credits_balance" do
      let(:params) do
        {
          code: "credits-alert",
          name: "Credits Balance Alert",
          alert_type: "wallet_credits_balance",
          thresholds: [{code: :notice, value: 100}]
        }
      end

      it "creates a wallet_credits_balance alert" do
        subject
        expect(json[:alert]).to include({
          lago_id: be_present,
          code: "credits-alert",
          alert_type: "wallet_credits_balance"
        })
      end
    end

    context "when alert_type is not a wallet type" do
      let(:params) do
        {
          code: "test",
          alert_type: "current_usage_amount",
          thresholds: [{code: :notice, value: 1000}]
        }
      end

      it "returns validation error" do
        subject
        expect(json).to eq({
          code: "validation_errors",
          error: "Unprocessable Entity",
          error_details: {alert_type: ["invalid_type"]},
          status: 422
        })
      end
    end

    context "when payload is missing required param" do
      %i[code thresholds].each do |field|
        it "returns error when #{field} is missing" do
          params.delete(field)
          subject
          expect(json).to match({
            code: "validation_errors",
            error: "Unprocessable Entity",
            error_details: {field => array_including("value_is_mandatory")},
            status: 422
          })
        end
      end

      it "returns error when alert_type is missing" do
        params.delete(:alert_type)
        subject
        expect(json).to eq({
          code: "validation_errors",
          error: "Unprocessable Entity",
          error_details: {alert_type: ["value_is_mandatory", "value_is_invalid"]},
          status: 422
        })
      end
    end

    context "when alert_type is not supported" do
      let(:params) do
        {
          code: "test",
          alert_type: "not_supported",
          thresholds: [{code: :notice, value: 1000}]
        }
      end

      it do
        subject
        expect(json).to eq({
          code: "validation_errors",
          error: "Unprocessable Entity",
          error_details: {alert_type: ["invalid_type"]},
          status: 422
        })
      end
    end
  end

  describe "GET /api/v1/customers/:external_id/wallets/:wallet_code/alerts/:code" do
    subject { get_with_token(organization, "/api/v1/customers/#{customer_external_id}/wallets/#{wallet_code}/alerts/#{code}") }

    it_behaves_like "requires API permission", "alert", "read"
    it_behaves_like "returns error if customer not found"
    it_behaves_like "returns error if wallet not found"

    it do
      subject
      expect(json[:alert]).to include({
        code:,
        lago_id: alert.id,
        alert_type: "wallet_balance_amount",
        previous_value: "800.0",
        name: "General Alert",
        created_at: be_present
      })
    end

    context "when alert is not found" do
      let(:alert) { nil }

      it do
        subject
        expect(response).to be_not_found_error("alert")
      end
    end
  end

  describe "PUT /api/v1/customers/:external_id/wallets/:wallet_code/alerts/:code" do
    subject { put_with_token(organization, "/api/v1/customers/#{customer_external_id}/wallets/#{wallet_code}/alerts/#{code}", {alert: params}) }

    let(:params) do
      {
        code: "updated-code",
        thresholds: [{code: :notice, value: 88_00}]
      }
    end

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if customer not found"
    it_behaves_like "returns error if wallet not found"

    it "updates the alert" do
      subject

      expect(json[:alert]).to include({
        lago_id: alert.id,
        lago_organization_id: organization.id,
        code: "updated-code",
        name: "General Alert",
        previous_value: "800.0",
        last_processed_at: be_present,
        created_at: be_present
      })
    end

    context "when alert is not found" do
      let(:alert) { nil }

      it do
        subject
        expect(response).to be_not_found_error("alert")
      end
    end
  end

  describe "DELETE /api/v1/customers/:external_id/wallets/:wallet_code/alerts/:code" do
    subject { delete_with_token(organization, "/api/v1/customers/#{customer_external_id}/wallets/#{wallet_code}/alerts/#{code}") }

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if customer not found"
    it_behaves_like "returns error if wallet not found"

    it "soft deletes the alert" do
      subject
      expect(alert.reload.deleted_at).to be_within(5.seconds).of(Time.current)
    end

    context "when alert is not found" do
      let(:alert) { nil }

      it do
        subject
        expect(response).to be_not_found_error("alert")
      end
    end
  end

  describe "POST /api/v1/customers/:external_id/wallets/:wallet_code/alerts (batch)" do
    subject { post_with_token(organization, "/api/v1/customers/#{customer_external_id}/wallets/#{wallet_code}/alerts", params) }

    let(:alert) { nil }
    let(:params) do
      {
        alerts: [
          {
            code: "alert1",
            name: "First Alert",
            alert_type: "wallet_balance_amount",
            thresholds: [{code: :notice, value: 1000}]
          },
          {
            code: "alert2",
            alert_type: "wallet_credits_balance",
            thresholds: [{value: 2000}]
          }
        ]
      }
    end

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if customer not found"
    it_behaves_like "returns error if wallet not found"

    it "creates multiple alerts" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:alerts].count).to eq 2

      expect(json[:alerts]).to match_array([
        include(code: "alert1"),
        include(code: "alert2")
      ])
    end

    context "when alerts are empty" do
      let(:params) { {alerts: []} }

      it "returns a validation error" do
        subject
        expect(response).to have_http_status(:bad_request)
        expect(json[:error]).to include("value is empty or invalid: alert")
      end
    end

    context "when several alerts are invalid" do
      let(:params) do
        {
          alerts: [
            {
              code: "duplicated",
              alert_type: "wallet_balance_amount",
              thresholds: [{value: 1000}]
            },
            {
              code: "alert2",
              alert_type: "invalid_type",
              thresholds: [{value: 2000}]
            },
            {
              code: "duplicated",
              alert_type: "wallet_balance_amount",
              thresholds: [{value: 3000}]
            }
          ]
        }
      end

      it "returns all the errors" do
        expect { subject }.not_to change(UsageMonitoring::Alert, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:code]).to eq "validation_errors"

        expect(json[:error_details]).to match(
          "1": match(params: params[:alerts][1], errors: include("invalid_type")),
          "2": match(params: params[:alerts][2], errors: include("alert_already_exists"))
        )
      end
    end
  end

  describe "DELETE /api/v1/customers/:external_id/wallets/:wallet_code/alerts" do
    subject { delete_with_token(organization, "/api/v1/customers/#{customer_external_id}/wallets/#{wallet_code}/alerts") }

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if customer not found"
    it_behaves_like "returns error if wallet not found"

    it "soft deletes all alerts for the wallets" do
      subject

      expect(response).to have_http_status(:ok)
    end

    context "when there are no alerts" do
      let(:alert) { nil }

      it "returns ok" do
        subject

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
