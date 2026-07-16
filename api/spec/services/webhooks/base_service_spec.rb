# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::BaseService do
  subject(:webhook_service) { WebhooksSpec::DummyClass.new(object:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:subscription) { create(:subscription, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:) }
  let(:object) { invoice }
  let(:previous_webhook) { nil }

  describe ".call" do
    it "creates a pending webhook" do
      webhook_service.call

      webhook = Webhook.order(created_at: :desc).first

      expect(webhook.status).to eq("pending")
      expect(webhook.retries).to be_zero
      expect(webhook.webhook_type).to eq("dummy.test")
      expect(webhook.endpoint).to eq(webhook.webhook_endpoint.webhook_url)
      expect(webhook.object_id).to eq(invoice.id)
      expect(webhook.object_type).to eq("Invoice")
      expect(webhook.http_status).to be_nil
      expect(webhook.response).to be_nil
      expect(webhook.payload.keys).to eq %w[webhook_type object_type organization_id dummy]
    end

    it "stores the payload on object storage instead of the database" do
      webhook_service.call

      webhook = Webhook.order(created_at: :desc).first

      expect(webhook.payload_key).to start_with("webhooks/")
      expect(webhook.read_attribute(:payload)).to be_nil
    end

    context "when organization has one webhook endpoint" do
      it "enqueues one http job" do
        webhook_service.call

        expect(SendHttpWebhookJob).to have_been_enqueued.once
      end
    end

    context "when organization has 2 webhook endpoints" do
      it "calls 2 webhooks" do
        create(:webhook_endpoint, organization:)
        object.reload
        webhook_service.call

        expect(SendHttpWebhookJob).to have_been_enqueued.twice
      end
    end

    context "without webhook endpoint" do
      let(:organization) { create(:organization) }

      before do
        organization.webhook_endpoints.destroy_all
      end

      it "does not create the webhook model" do
        webhook_service.call

        expect(SendHttpWebhookJob).not_to have_been_enqueued
        expect(Webhook.where(object: invoice)).not_to exist
      end
    end

    context "with deleted webhook endpoint" do
      before do
        endpoint = create(:webhook_endpoint, organization:)

        # Preload the webhook end-points
        invoice.organization.webhook_endpoints

        # Manually delete the first endpoint to simulate the race condition
        Organization.connection.execute("DELETE FROM webhook_endpoints WHERE id = '#{endpoint.id}'")
      end

      it "creates only one webhook" do
        expect { webhook_service.call }.to change(Webhook, :count).by(1)

        expect(SendHttpWebhookJob).to have_been_enqueued.once
      end
    end

    context "with event filtering enabled" do
      context "when event type does not match" do
        before do
          webhook_endpoint = organization.webhook_endpoints.first
          webhook_endpoint.event_types = ["other.type"]
          webhook_endpoint.save(validate: false) # disable validation because "other.type" isn't a correct event type
          object.reload
        end

        it "does not create the webhook model" do
          webhook_service.call

          expect(SendHttpWebhookJob).not_to have_been_enqueued
          expect(Webhook.where(object: invoice)).not_to exist
        end
      end

      context "when event type matches" do
        before do
          webhook_endpoint = organization.webhook_endpoints.first
          webhook_endpoint.event_types = ["dummy.test"]
          webhook_endpoint.save(validate: false) # disable validation because "dummy.test" isn't a correct event type
          object.reload
        end

        it "creates the webhook model" do
          webhook_service.call

          expect(SendHttpWebhookJob).to have_been_enqueued.once
          expect(Webhook.where(object: invoice)).to exist
        end
      end

      context "when event_types doesn't contain any types" do
        before do
          webhook_endpoint = organization.webhook_endpoints.first
          webhook_endpoint.event_types = []
          webhook_endpoint.save!
          object.reload
        end

        it "does not create the webhook model" do
          webhook_service.call

          expect(SendHttpWebhookJob).not_to have_been_enqueued
          expect(Webhook.where(object: invoice)).not_to exist
        end
      end

      context "when event type is null" do
        before do
          webhook_endpoint = organization.webhook_endpoints.first
          webhook_endpoint.event_types = nil
          webhook_endpoint.save!
          object.reload
        end

        it "creates the webhook model" do
          webhook_service.call

          expect(SendHttpWebhookJob).to have_been_enqueued.once
          expect(Webhook.where(object: invoice)).to exist
        end
      end
    end
  end
end

module WebhooksSpec
  class DummyClass < Webhooks::BaseService
    def current_organization
      @current_organization ||= object.organization
    end

    def object_serializer
      ::V1::InvoiceSerializer.new(
        object,
        root_name: "invoice"
      )
    end

    def webhook_type
      "dummy.test"
    end

    def object_type
      "dummy"
    end
  end
end
