# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::SecurityLogsController, clickhouse: true do
  let!(:stored_ids) do
    [
      {created_at: 1.hour.ago, logged_at: 1.hour.ago, log_type: "user", log_event: "user.signed_in", user:},
      {created_at: 2.hours.ago, logged_at: 2.hours.ago, log_type: "user", log_event: "other"},
      {created_at: 3.hours.ago, logged_at: 3.hours.ago, log_type: "api_key", log_event: "other", api_key:}
    ].map { |data| create(:clickhouse_security_log, organization:, **data).log_id }
  end

  let(:log_data) { {organization:, created_at: 1.day.ago, logged_at: 1.day.ago} }
  let(:user) { create(:membership, organization:).user }
  let(:api_key) { create(:api_key, organization:) }
  let(:organization) { create(:organization) }
  let(:params) { {} }
  let(:returned_ids) { json[:security_logs].map { |l| l[:log_id] } }

  describe "GET /api/v1/security_logs" do
    subject { get_with_token(organization, "/api/v1/security_logs", params) }

    let(:params) { {to_date: Time.current.iso8601} }

    context "with a free organization" do
      it "returns a forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:error]).to eq("Forbidden")
        expect(json[:code]).to eq("feature_unavailable")
      end
    end

    context "with a premium organization without the `security_logs` feature", :premium do
      it "returns a forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:code]).to eq("forbidden")
      end
    end

    context "with a premium organization with the `security_logs` feature", :premium do
      before { organization.update!(premium_integrations: ["security_logs"]) }

      include_examples "requires API permission", "security_log", "read"

      context "without filters" do
        it "returns security logs" do
          subject

          expect(response).to have_http_status(:success)
          expect(returned_ids).to eq(stored_ids)
        end
      end

      context "when to_date is missing" do
        let(:params) { {} }

        it "returns a validation error" do
          subject

          expect(response).to have_http_status(:unprocessable_content)
          expect(json[:error_details]).to include(:to_date)
        end
      end

      context "when filtering by from_date" do
        let(:params) { {to_date: Time.current.iso8601, from_date: 2.5.hours.ago.iso8601} }

        it "returns security logs for the specified date range" do
          subject

          expect(response).to have_http_status(:success)
          expect(returned_ids).to eq(stored_ids[..1])
        end
      end

      context "when filtering by user_ids" do
        let(:params) { {to_date: Time.current.iso8601, user_ids: [user.id]} }

        it "returns security logs for the specified filter" do
          subject

          expect(response).to have_http_status(:success)
          expect(returned_ids).to contain_exactly(stored_ids.first)
        end
      end

      context "when filtering by api_key_ids" do
        let(:params) { {to_date: Time.current.iso8601, api_key_ids: [api_key.id]} }

        it "returns security logs for the specified filter" do
          subject

          expect(response).to have_http_status(:success)
          expect(returned_ids).to contain_exactly(stored_ids.last)
        end
      end

      context "when filtering by log_types" do
        let(:params) { {to_date: Time.current.iso8601, log_types: ["user"]} }

        it "returns security logs for the specified filter" do
          subject

          expect(response).to have_http_status(:success)
          expect(returned_ids).to eq(stored_ids[..1])
        end
      end

      context "when filtering by log_events" do
        let(:params) { {to_date: Time.current.iso8601, log_events: ["user.signed_in"]} }

        it "returns security logs for the specified filter" do
          subject

          expect(response).to have_http_status(:success)
          expect(returned_ids).to contain_exactly(stored_ids.first)
        end
      end

      context "with pagination" do
        let(:params) { {to_date: Time.current.iso8601, page: 1, per_page: 1} }

        it "returns security logs with correct meta data" do
          subject

          expect(response).to have_http_status(:success)
          expect(returned_ids).to contain_exactly(stored_ids.first)
          expect(json[:meta][:current_page]).to eq(1)
          expect(json[:meta][:next_page]).to eq(2)
          expect(json[:meta][:prev_page]).to eq(nil)
          expect(json[:meta][:total_pages]).to eq(3)
          expect(json[:meta][:total_count]).to eq(3)
        end
      end
    end
  end

  describe "GET /api/v1/security_logs/:log_id" do
    subject { get_with_token(organization, "/api/v1/security_logs/#{stored_ids.first}", params) }

    context "with a free organization" do
      it "returns a forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:error]).to eq("Forbidden")
        expect(json[:code]).to eq("feature_unavailable")
      end
    end

    context "with a premium organization without the `security_logs` feature", :premium do
      it "returns a forbidden error" do
        subject

        expect(response).to have_http_status(:forbidden)
        expect(json[:code]).to eq("forbidden")
      end
    end

    context "with a premium organization with the `security_logs` feature", :premium do
      before { organization.update!(premium_integrations: ["security_logs"]) }

      include_examples "requires API permission", "security_log", "read"

      it "returns security log" do
        subject

        expect(response).to have_http_status(:success)
        expect(json[:security_log][:log_id]).to eq(stored_ids.first)
      end

      context "when security log does not exist" do
        subject { get_with_token(organization, "/api/v1/security_logs/unknown", params) }

        it "returns not found error" do
          subject

          expect(response).to be_not_found_error("security_log")
        end
      end
    end
  end
end
