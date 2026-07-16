# frozen_string_literal: true

require "rails_helper"

RSpec.describe SecurityLogsQuery, clickhouse: true do
  subject(:result) { described_class.call(organization:, pagination:, filters:) }

  let(:returned_ids) { result.security_logs.pluck(:log_id) }
  let(:organization) { security_log.organization }
  let(:security_log) { create(:clickhouse_security_log, organization: premium_organization) }
  let(:premium_organization) { create(:organization, premium_integrations: ["security_logs"]) }
  let(:pagination) { {page: 1, limit: 10} }
  let(:filters) { {to_date: Time.current} }

  before do
    allow(License).to receive(:premium?).and_return(true)
    security_log
  end

  describe ".available?" do
    subject { described_class.available? }

    include_context "with clickhouse availability"

    context "when clickhouse is available" do
      it { is_expected.to be true }
    end

    context "when clickhouse is not available" do
      let(:clickhouse_enabled) { nil }

      it { is_expected.to be false }
    end
  end

  describe "#call" do
    it "returns all security logs" do
      expect(result.security_logs.count).to eq(1)
      expect(returned_ids).to include(security_log.log_id)
    end

    context "when to_date is missing" do
      let(:filters) { {} }

      it "returns validation failure" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:to_date]).to eq(["value_is_mandatory"])
      end
    end

    context "with old security logs" do
      let(:old_security_log) do
        create(:clickhouse_security_log,
          organization: organization,
          logged_at: 91.days.ago)
      end

      before { old_security_log }

      it "excludes logs older than retention period" do
        expect(result.security_logs.count).to eq(1)
        expect(returned_ids).to eq([security_log.log_id])
      end
    end

    context "with pagination" do
      let(:pagination) { {page: 1, limit: 1} }

      it "applies the pagination" do
        expect(result).to be_success
        expect(result.security_logs.count).to eq(1)
        expect(result.security_logs.current_page).to eq(1)
        expect(result.security_logs.prev_page).to be_nil
        expect(result.security_logs.next_page).to be_nil
        expect(result.security_logs.total_pages).to eq(1)
        expect(result.security_logs.total_count).to eq(1)
      end
    end

    context "with from_date and to_date filters" do
      it "returns expected security logs" do
        filters = {from_date: security_log.logged_at + 1.day, to_date: security_log.logged_at + 2.days}
        expect(described_class.call(organization:, pagination:, filters:).security_logs).to be_empty

        filters = {from_date: security_log.logged_at - 1.day, to_date: security_log.logged_at + 1.day}
        expect(described_class.call(organization:, pagination:, filters:).security_logs.first.log_id).to eq(security_log.log_id)

        filters = {to_date: security_log.logged_at - 1.day}
        expect(described_class.call(organization:, pagination:, filters:).security_logs).to be_empty
      end
    end

    context "with api_key_ids filter" do
      it "returns expected security logs" do
        filters = {api_key_ids: [security_log.api_key_id], to_date: Time.current}
        expect(described_class.call(organization:, pagination:, filters:).security_logs.first.log_id).to eq(security_log.log_id)

        filters = {api_key_ids: ["other"], to_date: Time.current}
        expect(described_class.call(organization:, pagination:, filters:).security_logs).to be_empty
      end
    end

    context "with user_ids filter" do
      it "returns expected security logs" do
        filters = {user_ids: [security_log.user_id], to_date: Time.current}
        expect(described_class.call(organization:, pagination:, filters:).security_logs.first.log_id).to eq(security_log.log_id)

        filters = {user_ids: ["other"], to_date: Time.current}
        expect(described_class.call(organization:, pagination:, filters:).security_logs).to be_empty
      end
    end

    context "with log_types filter" do
      it "returns expected security logs" do
        filters = {log_types: [security_log.log_type], to_date: Time.current}
        expect(described_class.call(organization:, pagination:, filters:).security_logs.first.log_id).to eq(security_log.log_id)

        filters = {log_types: ["other"], to_date: Time.current}
        expect(described_class.call(organization:, pagination:, filters:).security_logs).to be_empty
      end
    end

    context "with log_events filter" do
      it "returns expected security logs" do
        filters = {log_events: [security_log.log_event], to_date: Time.current}
        expect(described_class.call(organization:, pagination:, filters:).security_logs.first.log_id).to eq(security_log.log_id)

        filters = {log_events: ["other"], to_date: Time.current}
        expect(described_class.call(organization:, pagination:, filters:).security_logs).to be_empty
      end
    end

    context "when clickhouse is not available" do
      before { ENV["LAGO_CLICKHOUSE_ENABLED"] = nil }

      after { ENV["LAGO_CLICKHOUSE_ENABLED"] = "true" }

      it "returns forbidden failure" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
        expect(result.error.code).to eq("feature_unavailable")
      end
    end

    context "when security_logs is not enabled" do
      let(:organization) { create(:organization, premium_integrations: []) }

      it "returns forbidden failure" do
        expect(result).to be_failure
        expect(result.error).to be_a(BaseService::ForbiddenFailure)
      end
    end
  end
end
