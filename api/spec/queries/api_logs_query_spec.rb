# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiLogsQuery, clickhouse: true do
  subject(:result) do
    described_class.call(organization:, pagination:, filters:)
  end

  let(:returned_ids) { result.api_logs.pluck(:request_id) }
  let(:organization) { api_log.organization }
  let(:api_log) { create(:clickhouse_api_log) }
  let(:pagination) { {page: 1, limit: 10} }
  let(:filters) { nil }

  before do
    api_log
  end

  it "returns all api logs" do
    expect(result.api_logs.count).to eq(1)
    expect(returned_ids).to include(api_log.request_id)
  end

  context "with old api logs" do
    let(:old_api_log) do
      create(
        :clickhouse_api_log,
        organization:,
        logged_at: 33.days.ago
      )
    end

    before do
      old_api_log
    end

    context "with audit_logs_period value" do
      before { organization.update(audit_logs_period: 30) }

      it "returns only recent ones" do
        expect(result.api_logs.count).to eq(1)
        expect(returned_ids).to eq([api_log.request_id])
      end
    end

    context "without audit_logs_period value" do
      before { organization.update(audit_logs_period: nil) }

      it "returns all" do
        expect(result.api_logs.count).to eq(2)
        expect(returned_ids).to eq([api_log.request_id, old_api_log.request_id])
      end
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 1, limit: 1} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.api_logs.count).to eq(1)
      expect(result.api_logs.current_page).to eq(1)
      expect(result.api_logs.prev_page).to be_nil
      expect(result.api_logs.next_page).to be_nil
      expect(result.api_logs.total_pages).to eq(1)
      expect(result.api_logs.total_count).to eq(1)
    end
  end

  context "with from_date and to_date filters" do
    it "returns expected api logs" do
      filters = {from_date: api_log.logged_at + 1.day}
      expect(described_class.call(organization:, pagination:, filters:).api_logs).to be_empty

      filters = {from_date: api_log.logged_at - 1.day, to_date: api_log.logged_at + 1.day}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {to_date: api_log.logged_at - 1.day}
      expect(described_class.call(organization:, pagination:, filters:).api_logs).to be_empty
    end
  end

  context "with api_key_ids filter" do
    it "returns expected api logs" do
      filters = {api_key_ids: [api_log.api_key_id]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {api_key_ids: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs).to be_empty
    end
  end

  context "with http_methods filter" do
    it "returns expected api logs" do
      filters = {http_methods: [api_log.http_method]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {http_methods: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs).to be_empty
    end
  end

  context "with http_statuses filter" do
    it "returns expected api logs" do
      filters = {http_statuses: api_log.http_status}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {http_statuses: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs).to be_empty
    end

    context "when succeeded" do
      it "returns expected api logs" do
        filters = {http_statuses: ["succeeded"]}
        expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)
      end
    end

    context "when failed" do
      let(:failed_api_log) { create(:clickhouse_api_log, organization:, http_status: 404) }

      before { failed_api_log }

      it "returns expected api logs" do
        filters = {http_statuses: ["failed"]}
        expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(failed_api_log.request_id)
      end
    end

    context "when not an array" do
      it "returns expected api logs" do
        filters = {http_statuses: 200}
        expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)
      end
    end
  end

  context "with api_version filter" do
    it "returns expected api logs" do
      filters = {api_version: api_log.api_version}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)
    end
  end

  context "with request_paths filter" do
    let(:api_log) { create(:clickhouse_api_log, request_path: "/v1/billable_metrics/111222333") }

    it "returns expected api logs" do
      filters = {request_paths: [api_log.request_path]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {request_paths: ["/v1/billable_metrics/*"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {request_paths: ["/v1/*/111222333"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {request_paths: ["*billable_metrics*"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {request_paths: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs).to be_empty
    end
  end

  context "with request_ids filter" do
    let(:filler_api_log) { create(:clickhouse_api_log, organization:, http_status: 404) }
    let(:sorted_ids) { [api_log.request_id, filler_api_log.request_id].sort }

    it "returns expected api logs" do
      filters = {request_ids: sorted_ids}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.map(&:request_id).sort).to eq(sorted_ids)

      filters = {request_ids: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs).to be_empty
    end
  end

  context "with clients filter" do
    it "returns expected api logs" do
      filters = {clients: [api_log.client]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs.first.request_id).to eq(api_log.request_id)

      filters = {clients: ["other"]}
      expect(described_class.call(organization:, pagination:, filters:).api_logs).to be_empty
    end
  end

  context "when api logs are not available" do
    before do
      ENV["LAGO_CLICKHOUSE_ENABLED"] = nil
    end

    it { expect(result).not_to be_success }
    it { expect(result).to be_failure }
    it { expect(result.error).to be_a(BaseService::ForbiddenFailure) }
    it { expect(result.error.code).to eq("feature_unavailable") }
  end
end
