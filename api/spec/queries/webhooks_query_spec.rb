# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhooksQuery do
  subject(:result) do
    described_class.call(organization:, pagination:, search_term:, filters:)
  end

  let(:returned_ids) { result.webhooks.pluck(:id) }

  let(:pagination) { nil }
  let(:search_term) { nil }
  let(:filters) { {webhook_endpoint_id: webhook_endpoint.id} }

  let(:organization) { webhook_endpoint.organization.reload }
  let(:webhook_endpoint) { create(:webhook_endpoint) }
  let(:webhook_succeeded) { create(:webhook, :succeeded, webhook_endpoint:) }
  let(:webhook_failed) { create(:webhook, :failed, webhook_endpoint:) }
  let(:webhook_other_type) { create(:webhook, :succeeded, webhook_endpoint:, webhook_type: "invoice.generated") }

  before do
    webhook_succeeded
    webhook_failed
    webhook_other_type
  end

  it "returns all webhooks" do
    expect(returned_ids.count).to eq(3)
    expect(returned_ids).to include(webhook_succeeded.id)
    expect(returned_ids).to include(webhook_failed.id)
    expect(returned_ids).to include(webhook_other_type.id)
  end

  context "when ordering by second criteria" do
    let(:webhook_failed) do
      create(
        :webhook,
        :failed,
        webhook_endpoint:,
        id: "00000000-0000-0000-0000-000000000000",
        created_at: webhook_succeeded.created_at + 1.second,
        updated_at: webhook_succeeded.updated_at
      )
    end

    it "returns a consistent list" do
      expect(result).to be_success
      expect(returned_ids.count).to eq(3)
      expect(returned_ids).to include(webhook_succeeded.id)
      expect(returned_ids).to include(webhook_failed.id)
      expect(returned_ids.index(webhook_succeeded.id)).to be > returned_ids.index(webhook_failed.id)
    end
  end

  context "with pagination" do
    let(:pagination) { {page: 2, limit: 2} }

    it "applies the pagination" do
      expect(result).to be_success
      expect(result.webhooks.count).to eq(1)
      expect(result.webhooks.current_page).to eq(2)
      expect(result.webhooks.prev_page).to eq(1)
      expect(result.webhooks.next_page).to be_nil
      expect(result.webhooks.total_pages).to eq(2)
      expect(result.webhooks.total_count).to eq(3)
    end
  end

  context "when text searching" do
    context "when search for event id" do
      let(:search_term) { webhook_succeeded.id.to_s }

      it "returns matching webhooks" do
        expect(result).to be_success
        expect(returned_ids.count).to eq(1)
        expect(returned_ids).to include(webhook_succeeded.id)
      end
    end

    context "when search for resource id" do
      let(:search_term) { webhook_succeeded.object_id.to_s }

      it "returns matching webhooks" do
        expect(result).to be_success
        expect(returned_ids.count).to eq(1)
        expect(returned_ids).to include(webhook_succeeded.id)
      end
    end
  end

  context "when filtering" do
    describe "status" do
      context "when filtering by valid status" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, statuses: ["failed"]} }

        it "returns only one webhook" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(webhook_failed.id)
        end
      end

      context "when filtering by invalid status" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, statuses: ["invalid_status"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "event type" do
      context "when filtering by valid event type" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, event_types: ["invoice.generated"]} }

        it "returns only matching webhooks" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(webhook_other_type.id)
        end
      end

      context "when filtering by invalid event type" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, event_types: ["invalid.event"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "http status" do
      context "when filtering by specific status code" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, http_statuses: ["200"]} }

        it "returns only matching webhooks" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(2)
          expect(returned_ids).to include(webhook_succeeded.id)
          expect(returned_ids).to include(webhook_other_type.id)
        end
      end

      context "when filtering by wildcard status code" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, http_statuses: ["5xx"]} }

        it "returns only matching webhooks" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(webhook_failed.id)
        end
      end

      context "when filtering by status code range" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, http_statuses: ["200-205"]} }

        it "returns only matching webhooks" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(2)
          expect(returned_ids).to include(webhook_succeeded.id)
          expect(returned_ids).to include(webhook_other_type.id)
        end
      end

      context "when filtering by timeout" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, http_statuses: ["timeout"]} }
        let(:webhook_failed) { create(:webhook, :failed, webhook_endpoint:, http_status: nil) }

        it "returns only matching webhooks" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(1)
          expect(returned_ids).to include(webhook_failed.id)
        end
      end

      context "when filtering by invalid http status format" do
        let(:filters) { {webhook_endpoint_id: webhook_endpoint.id, http_statuses: ["invalid_status"]} }

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end

    describe "date range" do
      context "when filtering by valid date range" do
        let(:filters) do
          {
            webhook_endpoint_id: webhook_endpoint.id,
            from_date: 2.hours.ago,
            to_date: 1.hour.ago
          }
        end

        it "returns webhooks updated within the date range" do
          expect(result).to be_success
          expect(returned_ids.count).to eq(0)
        end
      end

      context "when filtering with invalid date format" do
        let(:filters) do
          {
            webhook_endpoint_id: webhook_endpoint.id,
            from_date: "invalid_date",
            to_date: "invalid_date"
          }
        end

        it "returns a validation failure" do
          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::ValidationFailure)
        end
      end
    end
  end
end
