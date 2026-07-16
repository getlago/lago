# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::BillableMetricsController do
  let(:organization) { create(:organization) }

  describe "POST /api/v1/billable_metrics" do
    subject do
      post_with_token(
        organization,
        "/api/v1/billable_metrics",
        {billable_metric: create_params}
      )
    end

    let(:create_params) do
      {
        name: "BM1",
        code: "BM1_code",
        description: "description",
        aggregation_type: "sum_agg",
        field_name: "amount_sum",
        expression: "1 + 2",
        recurring: true,
        rounding_function: "round",
        rounding_precision: 2
      }
    end

    include_examples "requires API permission", "billable_metric", "write"

    it "creates a billable_metric" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:billable_metric][:lago_id]).to be_present
      expect(json[:billable_metric][:code]).to eq(create_params[:code])
      expect(json[:billable_metric][:name]).to eq(create_params[:name])
      expect(json[:billable_metric][:created_at]).to be_present
      expect(json[:billable_metric][:recurring]).to eq(create_params[:recurring])
      expect(json[:billable_metric][:expression]).to eq(create_params[:expression])
      expect(json[:billable_metric][:rounding_function]).to eq(create_params[:rounding_function])
      expect(json[:billable_metric][:rounding_precision]).to eq(create_params[:rounding_precision])
      expect(json[:billable_metric][:filters]).to eq([])
    end

    context "with weighted sum aggregation" do
      let(:create_params) do
        {
          name: "BM1",
          code: "BM1_code",
          description: "description",
          aggregation_type: "weighted_sum_agg",
          field_name: "amount_sum",
          recurring: true,
          weighted_interval: "seconds"
        }
      end

      it "creates a billable_metric" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:billable_metric][:lago_id]).to be_present
        expect(json[:billable_metric][:recurring]).to eq(create_params[:recurring])
        expect(json[:billable_metric][:aggregation_type]).to eq("weighted_sum_agg")
        expect(json[:billable_metric][:weighted_interval]).to eq("seconds")
      end
    end

    context "with filters" do
      let(:create_params) do
        {
          name: "BM1",
          code: "BM1_code",
          aggregation_type: "count_agg",
          filters: [
            {
              key: "key",
              values: ["value1", "value2"]
            }
          ]
        }
      end

      it "creates a billable_metric with filters" do
        subject

        expect(response).to have_http_status(:success)

        expect(json[:billable_metric][:lago_id]).to be_present
        expect(json[:billable_metric][:filters]).to eq([{key: "key", values: ["value1", "value2"]}])
      end
    end

    context "with invalid input" do
      let(:create_params) { "BL" }

      it "returns bad_request error" do
        subject
        expect(response).to have_http_status(:bad_request)
        expect(json).to eq({status: 400, error: "BadRequest: param is missing or the value is empty or invalid: billable_metric"})
      end
    end
  end

  describe "PUT /api/v1/billable_metrics/:code" do
    subject do
      put_with_token(
        organization,
        "/api/v1/billable_metrics/#{billable_metric_code}",
        {billable_metric: update_params}
      )
    end

    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:billable_metric_code) { billable_metric.code }
    let(:code) { "BM1_code" }
    let(:update_params) do
      {
        name: "BM1",
        code:,
        description: "description",
        aggregation_type: "sum_agg",
        field_name: "amount_sum"
      }
    end

    include_examples "requires API permission", "billable_metric", "write"

    it "updates a billable_metric" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:billable_metric][:lago_id]).to eq(billable_metric.id)
      expect(json[:billable_metric][:code]).to eq(update_params[:code])
      expect(json[:billable_metric][:filters]).to eq([])
    end

    context "when billable metric does not exist" do
      let(:billable_metric_code) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when billable metric code already exists in organization scope (validation error)" do
      let!(:another_metric) { create(:billable_metric, organization:) }
      let(:code) { another_metric.code }

      it "returns unprocessable_entity error" do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with weighted sum aggregation" do
      let(:update_params) do
        {
          name: "BM1",
          code: "BM1_code",
          description: "description",
          aggregation_type: "weighted_sum_agg",
          field_name: "amount_sum",
          recurring: true,
          weighted_interval: "seconds"
        }
      end

      it "updates a billable_metric" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:billable_metric][:lago_id]).to be_present
        expect(json[:billable_metric][:recurring]).to be_truthy
        expect(json[:billable_metric][:aggregation_type]).to eq("weighted_sum_agg")
        expect(json[:billable_metric][:weighted_interval]).to eq("seconds")
      end
    end
  end

  describe "GET /api/v1/billable_metrics/:code" do
    subject do
      get_with_token(organization, "/api/v1/billable_metrics/#{billable_metric_code}")
    end

    let(:billable_metric) { create(:billable_metric, organization:) }
    let(:billable_metric_code) { billable_metric.code }

    include_examples "requires API permission", "billable_metric", "read"

    it "returns a billable metric" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:billable_metric][:lago_id]).to eq(billable_metric.id)
      expect(json[:billable_metric][:code]).to eq(billable_metric.code)
    end

    context "when billable metric does not exist" do
      let(:billable_metric_code) { SecureRandom.uuid }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when billable metric is deleted" do
      before { billable_metric.discard! }

      it "returns not found" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/billable_metrics/:code" do
    subject do
      delete_with_token(organization, "/api/v1/billable_metrics/#{billable_metric_code}")
    end

    let!(:billable_metric) { create(:billable_metric, organization:) }
    let(:billable_metric_code) { billable_metric.code }

    include_examples "requires API permission", "billable_metric", "write"

    it "deletes a billable_metric" do
      expect { subject }.to change(BillableMetric, :count).by(-1)
    end

    it "deletes alerts associated with billable_metric" do
      create(:billable_metric_current_usage_amount_alert, billable_metric:, organization:)
      expect { subject }.to change(organization.alerts, :count).by(-1)
    end

    it "returns deleted billable_metric" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:billable_metric][:lago_id]).to eq(billable_metric.id)
      expect(json[:billable_metric][:code]).to eq(billable_metric.code)
    end

    context "when billable metric does not exist" do
      let(:billable_metric_code) { SecureRandom.uuid }

      it "returns not_found error" do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/billable_metrics" do
    subject { get_with_token(organization, "/api/v1/billable_metrics", params) }

    let!(:billable_metric) { create(:billable_metric, organization:) }
    let(:params) { {} }

    include_examples "requires API permission", "billable_metric", "read"

    it "returns billable metrics" do
      subject

      expect(response).to have_http_status(:success)
      expect(json[:billable_metrics].count).to eq(1)
      expect(json[:billable_metrics].first[:lago_id]).to eq(billable_metric.id)
      expect(json[:billable_metrics].first[:code]).to eq(billable_metric.code)
    end

    context "with pagination" do
      let(:params) { {page: 1, per_page: 1} }

      before { create(:billable_metric, organization:) }

      it "returns billable metrics with correct meta data" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:billable_metrics].count).to eq(1)
        expect(json[:meta][:current_page]).to eq(1)
        expect(json[:meta][:next_page]).to eq(2)
        expect(json[:meta][:prev_page]).to eq(nil)
        expect(json[:meta][:total_pages]).to eq(2)
        expect(json[:meta][:total_count]).to eq(2)
      end
    end
  end

  describe "POST /api/v1/billable_metrics/evaluate_expression" do
    subject do
      post_with_token(
        organization,
        "/api/v1/billable_metrics/evaluate_expression",
        {expression:, event:}
      )
    end

    let(:expression) { "round(event.properties.value)" }
    let(:event) { {code: "bm_code", timestamp: Time.current.to_i, properties: {value: "2.4"}} }

    include_examples "requires API permission", "billable_metric", "write"

    context "with valid inputs" do
      it "evaluates the expression" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:expression_result][:value]).to eq("2.0")
      end
    end

    context "with invalid inputs" do
      let(:event) { {} }
      let(:expression) { "" }

      it "returns unprocessable_entity error" do
        subject

        expect(response).to have_http_status(:unprocessable_content)
        expect(json[:error_details][:expression]).to eq(["value_is_mandatory"])
      end
    end
  end
end
