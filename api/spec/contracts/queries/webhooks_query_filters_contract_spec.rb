# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::WebhooksQueryFiltersContract do
  subject(:result) { described_class.new.call(filters.to_h) }

  let(:filters) { {} }

  context "when filtering by webhook_endpoint_id" do
    let(:filters) { {webhook_endpoint_id: "webhook-123"} }

    it "is valid" do
      expect(result.success?).to be(true)
    end

    context "when filter is blank" do
      let(:filters) { {webhook_endpoint_id: nil} }

      it "is invalid" do
        expect(result.success?).to be(false)
      end
    end
  end

  context "when filtering by status" do
    context "when filter is valid" do
      let(:filters) { {webhook_endpoint_id: "webhook-123", statuses: ["pending", "succeeded"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when status filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {webhook_endpoint_id: "webhook-123", statuses: "random"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({statuses: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {webhook_endpoint_id: "webhook-123", statuses: ["pending", "random"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({statuses: {1 => ["must be one of: pending, succeeded, failed, retrying"]}})
        end
      end
    end
  end

  context "when filtering by event_types" do
    context "when filter is valid" do
      let(:filters) { {webhook_endpoint_id: "webhook-123", event_types: ["invoice.created", "invoice.generated"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when event_types filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {webhook_endpoint_id: "webhook-123", event_types: "random"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({event_types: ["must be an array"]})
        end
      end

      context "when filter is an array with invalid values" do
        let(:filters) { {webhook_endpoint_id: "webhook-123", event_types: ["invoice.created", "random"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({event_types: {1 => ["must be one of: #{WebhookEndpoint::WEBHOOK_EVENT_TYPES.join(", ")}"]}})
        end
      end
    end
  end

  context "when filtering by http_statuses" do
    context "when filter is valid" do
      let(:filters) { {webhook_endpoint_id: "webhook-123", http_statuses: ["200", "5xx", "400-404", "timeout"]} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when http_statuses filter is invalid" do
      context "when filter is a string" do
        let(:filters) { {webhook_endpoint_id: "webhook-123", http_statuses: "random"} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({http_statuses: ["must be an array"]})
        end
      end

      context "when filter has invalid format" do
        let(:filters) { {webhook_endpoint_id: "webhook-123", http_statuses: ["200", "invalid"]} }

        it "is invalid" do
          expect(result.success?).to be(false)
          expect(result.errors.to_h).to include({http_statuses: {1 => ["is in invalid format"]}})
        end
      end
    end
  end

  context "when filtering by from_date and to_date" do
    context "when filters are valid" do
      let(:filters) { {webhook_endpoint_id: "webhook-123", from_date: 2.days.ago, to_date: Time.current} }

      it "is valid" do
        expect(result.success?).to be(true)
      end
    end

    context "when from_date is invalid" do
      let(:filters) { {webhook_endpoint_id: "webhook-123", from_date: "invalid date"} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include({from_date: ["must be a time"]})
      end
    end

    context "when to_date is invalid" do
      let(:filters) { {webhook_endpoint_id: "webhook-123", to_date: "invalid date"} }

      it "is invalid" do
        expect(result.success?).to be(false)
        expect(result.errors.to_h).to include({to_date: ["must be a time"]})
      end
    end
  end
end
