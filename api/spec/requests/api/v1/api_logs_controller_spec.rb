# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::ApiLogsController, clickhouse: true do
  subject { get_with_token(organization, path, params) }

  let(:organization) { api_log.organization }
  let(:api_log) { create(:clickhouse_api_log) }
  let(:params) { {} }

  describe "GET /api/v1/api_logs" do
    let(:path) { "/api/v1/api_logs" }

    context "with free organization" do
      it "returns a forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:error]).to eq("Forbidden")
        expect(json[:code]).to eq("feature_unavailable")
      end
    end

    context "with premium organization", :premium do
      include_examples "requires API permission", "api_log", "read"

      context "without filters" do
        let(:plain_api_log) { create(:clickhouse_api_log, organization:) }

        before { plain_api_log }

        it "returns api logs" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:api_logs].count).to eq(2)
          expect(json[:api_logs].map { |l| l[:request_id] }).to include(api_log.request_id, plain_api_log.request_id)
        end
      end

      context "when filtering by from_date" do
        let(:params) { {from_date: api_log.logged_at.iso8601} }

        it "returns api logs for the specified date range" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:api_logs].count).to eq(1)
          expect(json[:api_logs].first[:request_id]).to eq(api_log.request_id)
          expect(json[:api_logs].first[:logged_at]).to eq(api_log.logged_at.iso8601)
        end
      end

      context "when filtering by to_date" do
        let(:params) { {to_date: api_log.logged_at.iso8601} }
        let(:later_api_log) { create(:clickhouse_api_log, organization:, logged_at: 1.day.ago) }

        before { later_api_log }

        it "returns api logs for the specified date range" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:api_logs].count).to eq(1)
          expect(json[:api_logs].first[:request_id]).to eq(later_api_log.request_id)
          expect(json[:api_logs].first[:logged_at]).to eq(later_api_log.logged_at.iso8601)
        end
      end

      context "when filtering by http_methods" do
        let(:params) { {http_methods: ["put"]} }
        let(:put_api_log) { create(:clickhouse_api_log, organization:, http_method: "put") }

        before { put_api_log }

        it "returns api logs for the specified filter" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:api_logs].count).to eq(1)
          expect(json[:api_logs].first[:request_id]).to eq(put_api_log.request_id)
          expect(json[:api_logs].first[:http_method]).to eq(put_api_log.http_method)
        end
      end

      context "when filtering by http_statuses" do
        let(:params) { {http_statuses: [status]} }

        context "with success" do
          let(:status) { "succeeded" }

          it "returns api logs for the specified filter" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:api_logs].count).to eq(1)
            expect(json[:api_logs].first[:request_id]).to eq(api_log.request_id)
            expect(json[:api_logs].first[:http_status]).to eq(api_log.http_status)
          end
        end

        context "with failed" do
          let(:status) { "failed" }
          let(:failed_request_api_log) { create(:clickhouse_api_log, organization:, http_status: 404) }

          before { failed_request_api_log }

          it "returns api logs for the specified filter" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:api_logs].count).to eq(1)
            expect(json[:api_logs].first[:request_id]).to eq(failed_request_api_log.request_id)
            expect(json[:api_logs].first[:http_status]).to eq(failed_request_api_log.http_status)
          end
        end

        context "with http status number" do
          let(:status) { api_log.http_status }

          it "returns api logs for the specified filter" do
            subject

            expect(response).to have_http_status(:success)
            expect(json[:api_logs].count).to eq(1)
            expect(json[:api_logs].first[:request_id]).to eq(api_log.request_id)
            expect(json[:api_logs].first[:http_status]).to eq(api_log.http_status)
          end
        end
      end

      context "when filtering by api_version" do
        let(:params) { {api_version: "v1"} }

        it "returns api logs for the specified filter" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:api_logs].count).to eq(1)
          expect(json[:api_logs].first[:request_id]).to eq(api_log.request_id)
          expect(json[:api_logs].first[:api_version]).to eq(api_log.api_version)
        end
      end

      context "when filtering by request_paths" do
        let(:params) { {request_paths: ["*billable_metrics*"]} }
        let(:bm_api_log) { create(:clickhouse_api_log, organization:, request_path: "/v1/billable_metrics/") }

        before { bm_api_log }

        it "returns api logs for the specified filter" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:api_logs].count).to eq(1)
          expect(json[:api_logs].first[:request_id]).to eq(bm_api_log.request_id)
          expect(json[:api_logs].first[:request_path]).to eq(bm_api_log.request_path)
        end
      end

      context "with pagination" do
        let(:params) { {page: 1, per_page: 1} }

        before do
          create(:clickhouse_api_log, organization:)
        end

        it "returns activity logs with correct meta data" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:api_logs].count).to eq(1)
          expect(json[:meta][:current_page]).to eq(1)
          expect(json[:meta][:next_page]).to eq(2)
          expect(json[:meta][:prev_page]).to eq(nil)
          expect(json[:meta][:total_pages]).to eq(2)
          expect(json[:meta][:total_count]).to eq(2)
        end
      end
    end
  end

  describe "GET /api/v1/api_logs/:request_id" do
    let(:path) { "/api/v1/api_logs/#{api_log.request_id}" }

    context "with free organization" do
      it "returns a forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:error]).to eq("Forbidden")
        expect(json[:code]).to eq("feature_unavailable")
      end
    end

    context "with premium organization", :premium do
      include_examples "requires API permission", "api_log", "read"

      it "returns api logs" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:api_log]).to include(
          request_id: api_log.request_id,
          http_method: api_log.http_method,
          logged_at: api_log.logged_at.iso8601
        )
      end
    end
  end
end
