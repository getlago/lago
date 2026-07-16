# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityLogsQuery, clickhouse: true do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:)
  end

  let(:returned_ids) { result.activity_logs.pluck(:activity_id) }
  let(:organization) { activity_log.organization }
  let(:activity_log) { create(:clickhouse_activity_log) }
  let(:pagination) { {page: 1, limit: 10} }
  let(:filters) { nil }

  before do
    activity_log
  end

  it "returns all activity logs" do
    expect(result.activity_logs.count).to eq(1)
    expect(returned_ids).to include(activity_log.activity_id)
  end

  context "with old activity logs" do
    let(:old_activity_log) do
      create(:clickhouse_activity_log,
        organization: organization,
        resource: activity_log.resource,
        logged_at: 33.days.ago)
    end

    before do
      old_activity_log
    end

    context "with audit_logs_period value" do
      before { organization.update(audit_logs_period: 30) }

      it "returns only recent ones" do
        expect(result.activity_logs.count).to eq(1)
        expect(returned_ids).to eq([activity_log.activity_id])
      end
    end

    context "without audit_logs_period value" do
      before { organization.update(audit_logs_period: nil) }

      it "returns all" do
        expect(result.activity_logs.count).to eq(2)
        expect(returned_ids).to eq([activity_log.activity_id, old_activity_log.activity_id])
      end
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 1, limit: 1} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.activity_logs.count).to eq(1)
      expect(result.activity_logs.current_page).to eq(1)
      expect(result.activity_logs.prev_page).to be_nil
      expect(result.activity_logs.next_page).to be_nil
      expect(result.activity_logs.total_pages).to eq(1)
      expect(result.activity_logs.total_count).to eq(1)
    end
  end

  context "with from_date and to_date filters" do
    it "returns expected activity logs" do
      filters = {from_date: activity_log.logged_at + 1.day}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty

      filters = {from_date: activity_log.logged_at - 1.day, to_date: activity_log.logged_at + 1.day}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {to_date: activity_log.logged_at - 1.day}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with api_key_ids filter" do
    it "returns expected activity logs" do
      filters = {api_key_ids: [activity_log.api_key_id]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {api_key_ids: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with activity_ids filter" do
    it "returns expected activity logs" do
      filters = {activity_ids: [activity_log.activity_id]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {activity_ids: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with activity_types filter" do
    it "returns expected activity logs" do
      filters = {activity_types: [activity_log.activity_type]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {activity_types: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with activity_sources filter" do
    it "returns expected activity logs" do
      filters = {activity_sources: [activity_log.activity_source]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {activity_sources: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with user_emails filter" do
    it "returns expected activity logs" do
      filters = {user_emails: [activity_log.user.email]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {user_emails: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with external_customer_id filter" do
    it "returns expected activity logs" do
      filters = {external_customer_id: activity_log.external_customer_id}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {external_customer_id: "other"}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with external_subscription_id filter" do
    it "returns expected activity logs" do
      filters = {external_subscription_id: activity_log.external_subscription_id}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {external_subscription_id: "other"}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with resource_ids filter" do
    it "returns expected activity logs" do
      filters = {resource_ids: [activity_log.resource_id]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {resource_ids: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "with resource_types filter" do
    it "returns expected activity logs" do
      filters = {resource_types: [activity_log.resource_type]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs.first.activity_id).to eq(activity_log.activity_id)

      filters = {resource_types: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).activity_logs).to be_empty
    end
  end

  context "when activty logs are not available" do
    before do
      ENV["LAGO_CLICKHOUSE_ENABLED"] = nil
    end

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::ForbiddenFailure) }
    it { expect(result.error.code).to eq("feature_unavailable") }
  end
end
