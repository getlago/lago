# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resolvers::SecurityLogsResolver, clickhouse: true do
  let(:query) do
    <<~GQL
      query($toDatetime: ISO8601DateTime!) {
        securityLogs(toDatetime: $toDatetime) {
          collection {
            logId
            logType
            logEvent
            userEmail
          }
          metadata { currentPage, totalCount }
        }
      }
    GQL
  end
  let(:variables) { {toDatetime: Time.current.iso8601} }
  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

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

  context "when all conditions are met but no events exist", :premium do
    it "returns empty collection" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: "security_logs:view",
        query:,
        variables:
      )

      security_logs = result.dig("data", "securityLogs")
      expect(security_logs["collection"]).to eq([])
      expect(security_logs["metadata"]["totalCount"]).to eq(0)
    end
  end

  context "when security logs exist", :premium do
    let(:security_log) { create(:clickhouse_security_log, membership:, logged_at: 1.hour.ago) }

    before { security_log }

    it "returns the collection" do
      result = execute_graphql(
        current_user: membership.user,
        current_organization: organization,
        permissions: "security_logs:view",
        query:,
        variables:
      )

      security_logs = result.dig("data", "securityLogs")
      expect(security_logs["collection"].size).to eq(1)
      expect(security_logs["collection"].first["logId"]).to eq(security_log.log_id)
      expect(security_logs["metadata"]["totalCount"]).to eq(1)
    end
  end
end
