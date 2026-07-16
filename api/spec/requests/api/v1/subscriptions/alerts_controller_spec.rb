# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::Subscriptions::AlertsController do
  let(:external_id) { "sub+1" }
  let(:external_id_query_param) { external_id }
  let(:code) { "my-alert" }
  let(:organization) { create(:organization) }
  let(:subscription) { create(:subscription, external_id:, customer: create(:customer, organization: organization)) }
  let(:alert) { create(:alert, :processed, code:, subscription_external_id: external_id, organization:) }
  let(:deleted_alert) { create(:alert, :processed, deleted_at: Time.current, subscription_external_id: external_id, organization:, thresholds: []) }

  before do
    subscription
    alert
    deleted_alert
  end

  RSpec.shared_examples "returns error if subscription not found" do
    let(:external_id_query_param) { "not-found-id" }

    it do
      subject
      expect(response).to be_not_found_error("subscription")
    end
  end

  describe "GET /api/v1/subscriptions/:external_id/alerts" do
    subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/alerts") }

    it_behaves_like "requires API permission", "alert", "read"
    it_behaves_like "returns error if subscription not found"

    context "when there are alerts" do
      it "retrieves a paginated list of alerts" do
        subject
        expect(json[:alerts].sole).to include({
          code:,
          lago_id: alert.id,
          billable_metric: be_nil,
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

    context "when there is no alerts" do
      let(:alert) { nil }

      it do
        subject
        expect(json[:alerts]).to be_empty
        expect(json[:meta][:total_count]).to eq 0
      end
    end
  end

  describe "POST /api/v1/subscriptions/:external_id/alerts" do
    subject { post_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/alerts", {alert: params}) }

    let(:alert) { nil }
    let(:params) do
      {
        code: "test",
        name: "New Alert",
        alert_type: "current_usage_amount",
        thresholds: [
          {code: :notice, value: 1000},
          {code: :warn, value: 5000},
          {code: :alert, value: 2000, recurring: true}
        ]
      }
    end

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if subscription not found"

    it do
      subject

      expect(json[:alert]).to include({
        lago_id: be_present,
        code: "test",
        name: "New Alert",
        previous_value: "0.0",
        last_processed_at: be_nil,
        created_at: be_present
      })
    end

    context "when code already exists for this subscription" do
      it do
        create(:billable_metric_current_usage_amount_alert, organization:, code: params[:code], subscription_external_id: external_id)

        subject
        expect(json).to eq({
          code: "validation_errors",
          error: "Unprocessable Entity",
          error_details: {code: ["value_already_exist"]},
          status: 422
        })
      end
    end

    context "when payload is missing required param" do
      [:code, :alert_type, :thresholds].each do |field|
        it do
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

    context "with billable_metric" do
      let(:params) do
        {
          code: "bm",
          alert_type: "billable_metric_current_usage_amount",
          billable_metric_code: "bm_code",
          thresholds: [{code: :alert, value: 1000, recurring: true}]
        }
      end

      it "creates a billable_metric_current_usage_amount alert" do
        create(:billable_metric, code: "bm_code", organization:)
        subject
        expect(json[:alert]).to include({
          lago_id: be_present,
          alert_type: "billable_metric_current_usage_amount",
          code: "bm"
        })
      end

      context "when billable_metric is not found" do
        it do
          subject
          expect(response).to be_not_found_error("billable_metric")
        end
      end
    end
  end

  describe "GET /api/v1/subscriptions/:external_id/alerts/:code" do
    subject { get_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/alerts/#{code}") }

    it_behaves_like "requires API permission", "alert", "read"
    it_behaves_like "returns error if subscription not found"

    it do
      subject
      expect(json[:alert]).to include({
        code:,
        lago_id: alert.id,
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

  describe "PUT /api/v1/subscriptions/:external_id/alerts/:code" do
    subject { put_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/alerts/#{code}", {alert: params}) }

    let(:params) do
      {
        code: "test",
        thresholds: [{code: :notice, value: 88_00}]
      }
    end

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if subscription not found"

    it "updates the alert" do
      subject

      expect(json[:alert]).to include({
        lago_id: alert.id,
        lago_organization_id: organization.id,
        code: "test",
        name: "General Alert", # Not updated if not part of params
        previous_value: "800.0",
        last_processed_at: be_present,
        created_at: be_present
      })
    end

    context "when code already exists for this subscription" do
      it "does not update the alert" do
        create(:billable_metric_current_usage_amount_alert, organization:, code: params[:code], subscription_external_id: external_id)

        subject
        expect(json).to eq({
          code: "validation_errors",
          error: "Unprocessable Entity",
          error_details: {code: ["value_already_exist"]},
          status: 422
        })

        expect(alert.reload.name).to eq "General Alert"
        expect(alert.reload.code).to eq "my-alert"
      end
    end

    context "when trying to update alert_type" do
      let(:params) do
        {
          code: "test",
          alert_type: "billable_metric_current_usage_amount",
          billable_metric_code: create(:billable_metric, organization:).code
        }
      end

      it do
        subject
        expect(json).to eq({
          code: "validation_errors",
          error: "Unprocessable Entity",
          error_details: {billable_metric: ["value_must_be_blank"]}, # Because `param[:alert_type] as ignored
          status: 422
        })
      end
    end

    context "with billable_metric" do
      let(:alert) { create(:billable_metric_current_usage_amount_alert, :processed, code:, subscription_external_id: external_id, organization:) }
      let(:params) do
        {
          code: "bm",
          billable_metric_code: "bm_code",
          thresholds: [{code: :alert, value: 1000, recurring: true}]
        }
      end

      it "updates the billable_metric of the alert" do
        create(:billable_metric, code: "bm_code", organization:)
        subject
        expect(json[:alert]).to include({
          lago_id: alert.id,
          alert_type: "billable_metric_current_usage_amount",
          code: "bm",
          billable_metric: hash_including({code: "bm_code"})
        })
      end

      context "when billable_metric is not found" do
        it do
          subject
          expect(response).to be_not_found_error("billable_metric")
        end
      end
    end
  end

  describe "DELETE /api/v1/subscriptions/:external_id/alerts/:code" do
    subject { delete_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/alerts/#{code}") }

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if subscription not found"

    it "soft deletes the invoice" do
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

  describe "POST /api/v1/subscriptions/:external_id/alerts (batch)" do
    subject { post_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/alerts", params) }

    let(:alert) { nil }
    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:params) do
      {
        alerts: [
          {
            code: "alert1",
            name: "First Alert",
            alert_type: "current_usage_amount",
            thresholds: [{code: :notice, value: 1000}]
          },
          {
            code: "alert2",
            alert_type: "billable_metric_current_usage_amount",
            billable_metric_code: billable_metric.code,
            thresholds: [{value: 2000}]
          }
        ]
      }
    end

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if subscription not found"

    it "creates multiple alerts" do
      subject

      expect(response).to have_http_status(:ok)
      expect(json[:alerts].count).to eq 2
      expect(json[:alerts].map { |a| a[:code] }).to eq %w[alert1 alert2]
    end

    context "when one alert is invalid" do
      let(:params) do
        {
          alerts: [
            {
              code: "alert1",
              alert_type: "current_usage_amount",
              thresholds: [{value: 1000}]
            },
            {
              code: "alert2",
              alert_type: "current_usage_amount",
              thresholds: [{value: 2000}]
            }
          ]
        }
      end

      it "returns validation errors and creates no alerts" do
        expect { subject }.not_to change(UsageMonitoring::Alert, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:code]).to eq "validation_errors"
      end
    end

    context "when alerts is empty" do
      let(:params) { {alerts: []} }

      it "returns a validation error" do
        subject
        expect(response).to have_http_status(:bad_request)
        expect(json[:error]).to include("value is empty or invalid: alert")
      end
    end

    context "when there are several alerts invalid" do
      let(:params) do
        {
          alerts: [
            {
              code: "duplicated",
              alert_type: "current_usage_amount",
              thresholds: [{value: 1000}]
            },
            {
              code: "alert2",
              alert_type: "invalid_type",
              thresholds: [{value: 2000}]
            },
            {
              code: "billable_metric_not_found",
              alert_type: "billable_metric_current_usage_amount",
              billable_metric_code: "this_one_will_not_be_found",
              thresholds: [{value: 10}]
            },
            {
              code: "duplicated",
              alert_type: "billable_metric_current_usage_amount",
              billable_metric_code: billable_metric.code,
              thresholds: [{value: 11}]
            }
          ]
        }
      end

      it "returns all the errors" do
        expect { subject }.not_to change(UsageMonitoring::Alert, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json[:code]).to eq "validation_errors"
        errors = json[:error_details]
        alert_params = params[:alerts]
        expect(errors[:"1"][:params]).to eq(alert_params[1])
        expect(errors[:"1"][:errors]).to include("invalid_type")

        expect(errors[:"2"][:params]).to eq(alert_params[2])
        expect(errors[:"2"][:errors]).to include("billable_metric_not_found")

        expect(errors[:"3"][:params]).to eq(alert_params[3])
        # type is already taken
        expect(errors[:"3"][:errors]).to include("value_already_exist")
      end
    end
  end

  describe "DELETE /api/v1/subscriptions/:external_id/alerts" do
    subject { delete_with_token(organization, "/api/v1/subscriptions/#{external_id_query_param}/alerts") }

    it_behaves_like "requires API permission", "alert", "write"
    it_behaves_like "returns error if subscription not found"

    it "soft deletes all alerts for the subscription" do
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
