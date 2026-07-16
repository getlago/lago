# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::ApiLogsResolver, clickhouse: true do
  let(:required_permission) { "audit_logs:view" }
  let(:query) { build_query(limit: 5) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:api_log) { create(:clickhouse_api_log, membership:, logged_at: Time.iso8601("2025-09-08T15:04:45.016Z")) }

  before { api_log }

  def build_query(limit: 5, filters: "")
    <<~GQL
      query {
        apiLogs(limit: #{limit}#{", #{filters}" if filters.present?}) {
          collection {
            requestId
          }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  def execute_and_get_collection(filters = "")
    result = execute_query(query: build_query(filters:))

    result.dig("data", "apiLogs", "collection")
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "audit_logs:view"

  shared_examples "blocked feature" do |message|
    it "returns an error" do
      result = execute_query(query:)
      expect_graphql_error(result:, message:)
    end
  end

  context "without premium feature" do
    it_behaves_like "blocked feature", "unauthorized"
  end

  context "without database configuration", :premium do
    before do
      ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
      ENV["LAGO_KAFKA_API_LOGS_TOPIC"] = nil
      ENV["LAGO_CLICKHOUSE_ENABLED"] = nil
    end

    it_behaves_like "blocked feature", "feature_unavailable"
  end

  context "with premium feature", :premium do
    it "returns the list of api logs" do
      result = execute_query(
        query:
      )

      api_logs_response = result["data"]["apiLogs"]

      expect(api_logs_response["collection"].count).to eq(organization.api_logs.count)
      expect(api_logs_response["collection"].first["requestId"]).to eq(api_log.request_id)

      expect(api_logs_response["metadata"]["currentPage"]).to eq(1)
      expect(api_logs_response["metadata"]["totalCount"]).to eq(1)
    end

    context "with httpStatuses filter" do
      let(:failed_api_log) { create(:clickhouse_api_log, membership:, http_status: 404) }

      before { failed_api_log }

      context "with string" do
        let(:http_status) { "failed" }

        it "return failed api logs" do
          result = execute_query(query: build_query(filters: "httpStatuses: [#{http_status}]"))

          api_logs_response = result["data"]["apiLogs"]

          expect(api_logs_response["collection"].first["requestId"]).to eq(failed_api_log.request_id)

          expect(api_logs_response["metadata"]["currentPage"]).to eq(1)
          expect(api_logs_response["metadata"]["totalCount"]).to eq(1)
        end
      end

      context "with integer" do
        let(:http_status) { 404 }

        it "return failed api logs" do
          result = execute_query(
            query: build_query(filters: "httpStatuses: [#{http_status}]")
          )

          api_logs_response = result["data"]["apiLogs"]

          expect(api_logs_response["collection"].first["requestId"]).to eq(failed_api_log.request_id)

          expect(api_logs_response["metadata"]["currentPage"]).to eq(1)
          expect(api_logs_response["metadata"]["totalCount"]).to eq(1)
        end
      end
    end

    context "with httpMethods filter" do
      it "return api logs with the http method" do
        api_logs = execute_and_get_collection("httpMethods: [post]")
        expect(api_logs.count).to eq(1)

        api_logs = execute_and_get_collection("httpMethods: [put]")
        expect(api_logs.count).to eq(0)
      end
    end

    context "with apiKeyIds filter" do
      it "return api logs with the api key id" do
        api_logs = execute_and_get_collection("apiKeyIds: [\"#{api_log.api_key_id}\"]")
        expect(api_logs.count).to eq(1)

        api_logs = execute_and_get_collection("apiKeyIds: [\"other\"]")
        expect(api_logs.count).to eq(0)
      end
    end

    context "with requestIds filter" do
      it "return api logs with the request id" do
        api_logs = execute_and_get_collection("requestIds: [\"#{api_log.request_id}\"]")
        expect(api_logs.count).to eq(1)

        api_logs = execute_and_get_collection("requestIds: [\"other\"]")
        expect(api_logs.count).to eq(0)
      end
    end

    context "with requestPaths filter" do
      it "return api logs with the request path" do
        api_logs = execute_and_get_collection("requestPaths: [\"#{api_log.request_path}\"]")
        expect(api_logs.count).to eq(1)

        api_logs = execute_and_get_collection("requestPaths: [\"other\"]")
        expect(api_logs.count).to eq(0)
      end
    end

    context "with fromDate filter" do
      context "when fromDate is a date" do
        it "returns expected activity logs" do
          api_logs = execute_and_get_collection("fromDate: \"2025-09-08\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("fromDate: \"2025-09-09\"")
          expect(api_logs.count).to eq(0)
        end
      end

      context "when fromDate is a datetime" do
        it "returns expected activity logs" do
          api_logs = execute_and_get_collection("fromDate: \"2025-09-08T15:00:00Z\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("fromDate: \"2025-09-08T16:00:00+01:00\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("fromDate: \"2025-09-08T15:10:00Z\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("fromDate: \"2025-09-09T16:00:00+02:00\"")
          expect(api_logs.count).to eq(0)
        end
      end
    end

    context "with toDate filter" do
      context "when toDate is a date" do
        let(:query) {}

        it "returns expected activity logs" do
          api_logs = execute_and_get_collection("toDate: \"2025-09-09\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("toDate: \"2025-09-08\"")
          expect(api_logs.count).to eq(0)
        end
      end

      context "when toDate is a datetime" do
        it "returns expected activity logs" do
          api_logs = execute_and_get_collection("toDate: \"2025-09-09T15:15:00Z\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("toDate: \"2025-09-08T16:15:00+01:00\"")
          expect(api_logs.count).to eq(0)

          api_logs = execute_and_get_collection("toDate: \"2025-09-08T15:00:00Z\"")
          expect(api_logs.count).to eq(0)
        end
      end
    end

    context "with fromDatetime filter" do
      context "when fromDatetime is a date" do
        it "returns expected activity logs" do
          activity_logs = execute_and_get_collection("fromDatetime: \"2025-09-08\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("fromDatetime: \"2025-09-09\"")
          expect(activity_logs.count).to eq(0)
        end
      end

      context "when fromDatetime is a datetime" do
        it "returns expected activity logs" do
          activity_logs = execute_and_get_collection("fromDatetime: \"2025-09-08T15:00:00Z\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("fromDatetime: \"2025-09-08T16:00:00+01:00\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("fromDatetime: \"2025-09-08T15:10:00Z\"")
          expect(activity_logs.count).to eq(0)

          activity_logs = execute_and_get_collection("fromDatetime: \"2025-09-08T16:00:00+02:00\"")
          expect(activity_logs.count).to eq(1)
        end
      end
    end

    context "with toDatetime filter" do
      context "when toDatetime is a date" do
        let(:query) {}

        it "returns expected activity logs" do
          api_logs = execute_and_get_collection("toDatetime: \"2025-09-09\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("toDatetime: \"2025-09-08\"")
          expect(api_logs.count).to eq(0)
        end
      end

      context "when toDatetime is a datetime" do
        it "returns expected activity logs" do
          api_logs = execute_and_get_collection("toDatetime: \"2025-09-08T15:15:00Z\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("toDatetime: \"2025-09-08T16:15:00+01:00\"")
          expect(api_logs.count).to eq(1)

          api_logs = execute_and_get_collection("toDatetime: \"2025-09-08T15:00:00Z\"")
          expect(api_logs.count).to eq(0)

          api_logs = execute_and_get_collection("toDatetime: \"2025-09-08T16:00:00+02:00\"")
          expect(api_logs.count).to eq(0)
        end
      end
    end
  end
end
