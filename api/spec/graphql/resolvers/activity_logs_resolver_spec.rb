# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::ActivityLogsResolver, clickhouse: true do
  let(:required_permission) { "audit_logs:view" }
  let(:query) { build_query(limit: 5) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:clickhouse_activity_log) { create(:clickhouse_activity_log, membership:, logged_at: Time.iso8601("2025-09-08T15:04:45.016Z")) }

  before { clickhouse_activity_log }

  def build_query(limit: 5, filters: "")
    <<~GQL
      query {
        activityLogs(limit: #{limit}#{", #{filters}" if filters.present?}) {
          collection {
            activityId
          }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end

  def execute_and_get_collection(filters = "")
    result = execute_query(query: build_query(filters:))

    result.dig("data", "activityLogs", "collection")
  end

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "audit_logs:view"

  shared_examples "blocked feature" do |message|
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:
      )

      expect_graphql_error(result:, message:)
    end
  end

  context "without premium feature" do
    it_behaves_like "blocked feature", "unauthorized"
  end

  context "without database configuration", :premium do
    before do
      ENV["LAGO_KAFKA_BOOTSTRAP_SERVERS"] = nil
      ENV["LAGO_KAFKA_ACTIVITY_LOGS_TOPIC"] = nil
      ENV["LAGO_CLICKHOUSE_ENABLED"] = nil
    end

    it_behaves_like "blocked feature", "feature_unavailable"
  end

  context "with premium feature", :premium do
    it "returns the list of activity logs" do
      result = execute_query(query:)
      activity_logs_response = result["data"]["activityLogs"]

      expect(activity_logs_response["collection"].count).to eq(organization.activity_logs.count)
      expect(activity_logs_response["collection"].first["activityId"]).to eq(clickhouse_activity_log.activity_id)

      expect(activity_logs_response["metadata"]["currentPage"]).to eq(1)
      expect(activity_logs_response["metadata"]["totalCount"]).to eq(1)
    end

    context "with fromDate filter" do
      context "when fromDate is a date" do
        it "returns expected activity logs" do
          activity_logs = execute_and_get_collection("fromDate: \"2025-09-08\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("fromDate: \"2025-09-09\"")
          expect(activity_logs.count).to eq(0)
        end
      end

      context "when fromDate is a datetime" do
        it "returns expected activity logs" do
          activity_logs = execute_and_get_collection("fromDate: \"2025-09-08T15:00:00Z\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("fromDate: \"2025-09-08T16:00:00+01:00\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("fromDate: \"2025-09-09T15:10:00Z\"")
          expect(activity_logs.count).to eq(0)
        end
      end
    end

    context "with toDate filter" do
      context "when toDate is a date" do
        let(:query) {}

        it "returns expected activity logs" do
          activity_logs = execute_and_get_collection("toDate: \"2025-09-09\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("toDate: \"2025-09-08\"")
          expect(activity_logs.count).to eq(0)
        end
      end

      context "when toDate is a datetime" do
        it "returns expected activity logs" do
          activity_logs = execute_and_get_collection("toDate: \"2025-09-09T15:15:00Z\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("toDate: \"2025-09-08T16:15:00+01:00\"")
          expect(activity_logs.count).to eq(0)

          activity_logs = execute_and_get_collection("toDate: \"2025-09-08T15:00:00Z\"")
          expect(activity_logs.count).to eq(0)

          activity_logs = execute_and_get_collection("toDate: \"2025-09-08T16:00:00+02:00\"")
          expect(activity_logs.count).to eq(0)
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
          activity_logs = execute_and_get_collection("toDatetime: \"2025-09-09\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("toDatetime: \"2025-09-08\"")
          expect(activity_logs.count).to eq(0)
        end
      end

      context "when toDatetime is a datetime" do
        it "returns expected activity logs" do
          activity_logs = execute_and_get_collection("toDatetime: \"2025-09-08T15:15:00Z\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("toDatetime: \"2025-09-08T16:15:00+01:00\"")
          expect(activity_logs.count).to eq(1)

          activity_logs = execute_and_get_collection("toDatetime: \"2025-09-08T15:00:00Z\"")
          expect(activity_logs.count).to eq(0)

          activity_logs = execute_and_get_collection("toDatetime: \"2025-09-08T16:00:00+02:00\"")
          expect(activity_logs.count).to eq(0)
        end
      end
    end

    context "with apiKeyIds filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("apiKeyIds: [\"#{clickhouse_activity_log.api_key_id}\"]")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("apiKeyIds: [\"other\"]")
        expect(activity_logs.count).to eq(0)
      end
    end

    context "with activityIds filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("activityIds: [\"#{clickhouse_activity_log.activity_id}\"]")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("activityIds: [\"other\"]")
        expect(activity_logs.count).to eq(0)
      end
    end

    context "with activityTypes filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("activityTypes: [billable_metric_created]")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("activityTypes: [billable_metric_deleted]")
        expect(activity_logs.count).to eq(0)
      end
    end

    context "with activitySources filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("activitySources: [api]")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("activitySources: [front]")
        expect(activity_logs.count).to eq(0)
      end
    end

    context "with userEmails filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("userEmails: [\"#{clickhouse_activity_log.user.email}\"]")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("userEmails: [\"other\"]")
        expect(activity_logs.count).to eq(0)
      end
    end

    context "with externalCustomerId filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("externalCustomerId: \"#{clickhouse_activity_log.external_customer_id}\"")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("externalCustomerId: \"other\"")
        expect(activity_logs.count).to eq(0)
      end
    end

    context "with externalSubscriptionId filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("externalSubscriptionId: \"#{clickhouse_activity_log.external_subscription_id}\"")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("externalSubscriptionId: \"other\"")
        expect(activity_logs.count).to eq(0)
      end
    end

    context "with resourceIds filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("resourceIds: [\"#{clickhouse_activity_log.resource_id}\"]")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("resourceIds: [\"other\"]")
        expect(activity_logs.count).to eq(0)
      end
    end

    context "with resourceTypes filter" do
      it "returns expected activity logs" do
        activity_logs = execute_and_get_collection("resourceTypes: [billable_metric]")
        expect(activity_logs.count).to eq(1)

        activity_logs = execute_and_get_collection("resourceTypes: [coupon]")
        expect(activity_logs.count).to eq(0)
      end
    end
  end
end
