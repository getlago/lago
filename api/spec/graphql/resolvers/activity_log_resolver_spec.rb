# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::ActivityLogResolver, clickhouse: true do
  let(:required_permission) { "audit_logs:view" }
  let(:query) do
    <<~GQL
      query($activityLogId: ID!) {
        activityLog(activityId: $activityLogId) {
          activityId
          activityObjectChanges
        }
      }
    GQL
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:clickhouse_activity_log) { create(:clickhouse_activity_log, membership:) }

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "audit_logs:view"

  shared_examples "blocked feature" do |message|
    it "returns an error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {activityLogId: clickhouse_activity_log.activity_id}
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
    it "returns a single activity log with parsed object changes" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: required_permission,
        query:,
        variables: {activityLogId: clickhouse_activity_log.activity_id}
      )

      activity_log_response = result["data"]["activityLog"]

      expect(activity_log_response["activityId"]).to eq(clickhouse_activity_log.activity_id)
      expect(activity_log_response["activityObjectChanges"]).to eq("foo" => {"old" => "bar", "new" => "baz"})
    end

    context "when activity log is not found" do
      it "returns an error" do
        result = execute_graphql(
          current_user: membership.user,
          current_organization: organization,
          permissions: required_permission,
          query:,
          variables: {activityLogId: "invalid"}
        )

        expect_graphql_error(result:, message: "Resource not found")
      end
    end
  end
end
