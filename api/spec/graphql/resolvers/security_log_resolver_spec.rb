# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::SecurityLogResolver, clickhouse: true do
  let(:query) do
    <<~GQL
      query($logId: ID!) {
        securityLog(logId: $logId) {
          logId
          logType
          logEvent
          userEmail
        }
      }
    GQL
  end
  let(:variables) { {logId: security_log.log_id} }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:security_log) { create(:clickhouse_security_log, membership:) }

  before { organization.update!(premium_integrations: ["security_logs"]) }

  include_context "with clickhouse availability"

  it_behaves_like "requires current user"
  it_behaves_like "requires current organization"
  it_behaves_like "requires permission", "security_logs:view"

  context "without premium license" do
    it "returns feature_unavailable error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: "security_logs:view",
        query:,
        variables:
      )

      expect_graphql_error(result:, message: "feature_unavailable")
    end
  end

  context "when clickhouse is not available", :premium do
    let(:clickhouse_enabled) { nil }

    it "returns feature_unavailable error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: "security_logs:view",
        query:,
        variables:
      )

      expect_graphql_error(result:, message: "feature_unavailable")
    end
  end

  context "when security_logs is not enabled", :premium do
    before { organization.update!(premium_integrations: []) }

    it "returns feature_unavailable error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: "security_logs:view",
        query:,
        variables:
      )

      expect_graphql_error(result:, message: "feature_unavailable")
    end
  end

  context "when all conditions are met and log exists", :premium do
    it "returns the security log" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: "security_logs:view",
        query:,
        variables:
      )

      data = result.dig("data", "securityLog")
      expect(data["logId"]).to eq(security_log.log_id)
      expect(data["logType"]).to eq(security_log.log_type)
      expect(data["logEvent"]).to eq(security_log.log_event.tr(".", "_"))
    end
  end

  context "when log does not exist", :premium do
    let(:variables) { {logId: "non-existent-id"} }

    it "returns not_found error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: "security_logs:view",
        query:,
        variables:
      )

      expect_graphql_error(result:, message: "not_found")
    end
  end

  context "when log is outside retention period", :premium do
    let(:security_log) { create(:clickhouse_security_log, membership:, logged_at: 91.days.ago) }

    it "returns not_found error" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: "security_logs:view",
        query:,
        variables:
      )

      expect_graphql_error(result:, message: "not_found")
    end
  end
end
