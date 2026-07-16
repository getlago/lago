# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::ActivityLogsController, clickhouse: true do
  let(:organization) { activity_log.organization }
  let(:params) { {} }

  describe "GET /api/v1/activity_logs" do
    subject { get_with_token(organization, "/api/v1/activity_logs", params) }

    let(:activity_log) { create(:clickhouse_activity_log) }
    let(:invoice_activity_log) do
      create(
        :clickhouse_activity_log,
        organization_id: organization.id,
        external_customer_id: "ext_123",
        external_subscription_id: "ext_456",
        resource: invoice,
        activity_type: "invoice.created",
        activity_source: "front",
        logged_at: 1.day.ago
      )
    end
    let(:invoice) { create(:invoice, organization:) }

    before do
      activity_log
      invoice_activity_log
    end

    context "with free organization" do
      it "returns a forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:error]).to eq("Forbidden")
        expect(json[:code]).to eq("feature_unavailable")
      end
    end

    context "with premium organization", :premium do
      include_examples "requires API permission", "activity_log", "read"

      it "returns activity logs" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:activity_logs].count).to eq(2)
        expect(json[:activity_logs].map { |l| l[:activity_id] }).to include(activity_log.activity_id, invoice_activity_log.activity_id)
      end

      context "when filtering by external_customer_id" do
        let(:params) { {external_customer_id: activity_log.external_customer_id} }

        it "returns activity logs for the specified external customer" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(activity_log.activity_id)
          expect(json[:activity_logs].first[:external_customer_id]).to eq(activity_log.external_customer_id)
        end
      end

      context "when filtering by external_subscription_id" do
        let(:params) { {external_subscription_id: activity_log.external_subscription_id} }

        it "returns activity logs for the specified external subscription" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(activity_log.activity_id)
          expect(json[:activity_logs].first[:external_subscription_id]).to eq(activity_log.external_subscription_id)
        end
      end

      context "when filtering by resource_id" do
        let(:params) { {resource_ids: [activity_log.resource_id]} }

        it "returns activity logs for the specified resource" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(activity_log.activity_id)
          expect(json[:activity_logs].first[:resource_id]).to eq(activity_log.resource_id)
        end
      end

      context "when filtering by resource_type" do
        let(:params) { {resource_types: [activity_log.resource_type]} }

        it "returns activity logs for the specified resource type" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(activity_log.activity_id)
          expect(json[:activity_logs].first[:resource_type]).to eq(activity_log.resource_type)
        end
      end

      context "when filtering by user_email" do
        let(:params) { {user_emails: [activity_log.user.email]} }

        it "returns activity logs for the specified user email" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(activity_log.activity_id)
          expect(json[:activity_logs].first[:user_email]).to eq(activity_log.user.email)
        end
      end

      context "when filtering by activity_type" do
        let(:params) { {activity_types: [activity_log.activity_type]} }

        it "returns activity logs for the specified activity type" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(activity_log.activity_id)
          expect(json[:activity_logs].first[:activity_type]).to eq(activity_log.activity_type)
        end
      end

      context "when filtering by activity_source" do
        let(:params) { {activity_sources: [activity_log.activity_source]} }

        it "returns activity logs for the specified activity source" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(activity_log.activity_id)
          expect(json[:activity_logs].first[:activity_source]).to eq(activity_log.activity_source)
        end
      end

      context "when filtering by from_date" do
        let(:params) { {from_date: activity_log.logged_at.iso8601} }

        it "returns activity logs for the specified date range" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(activity_log.activity_id)
          expect(json[:activity_logs].first[:logged_at]).to eq(activity_log.logged_at.iso8601)
        end
      end

      context "when filtering by to_date" do
        let(:params) { {to_date: activity_log.logged_at.iso8601} }

        it "returns activity logs for the specified date range" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:activity_logs].first[:activity_id]).to eq(invoice_activity_log.activity_id)
          expect(json[:activity_logs].first[:logged_at]).to eq(invoice_activity_log.logged_at.iso8601)
        end
      end

      context "with pagination" do
        let(:params) { {page: 1, per_page: 1} }

        it "returns activity logs with correct meta data" do
          subject

          expect(response).to have_http_status(:success)
          expect(json[:activity_logs].count).to eq(1)
          expect(json[:meta][:current_page]).to eq(1)
          expect(json[:meta][:next_page]).to eq(2)
          expect(json[:meta][:prev_page]).to eq(nil)
          expect(json[:meta][:total_pages]).to eq(2)
          expect(json[:meta][:total_count]).to eq(2)
        end
      end
    end
  end

  describe "GET /api/v1/activity_logs/:activity_id" do
    subject { get_with_token(organization, "/api/v1/activity_logs/#{activity_log.activity_id}", params) }

    let(:activity_log) { create(:clickhouse_activity_log) }

    context "with free organization" do
      it "returns a forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:error]).to eq("Forbidden")
        expect(json[:code]).to eq("feature_unavailable")
      end
    end

    context "with premium organization", :premium do
      include_examples "requires API permission", "activity_log", "read"

      it "returns activity logs" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:activity_log]).to include(
          activity_id: activity_log.activity_id,
          activity_source: activity_log.activity_source,
          logged_at: activity_log.logged_at.iso8601
        )
      end
    end
  end
end
