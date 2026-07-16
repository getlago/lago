# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookEndpoint do
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:webhooks).dependent(:delete_all) }

  it { is_expected.to validate_presence_of(:webhook_url) }

  describe "validations" do
    subject(:webhook_endpoint) { build(:webhook_endpoint) }

    describe "of webhook url uniqueness" do
      let(:errors) { webhook_endpoint.errors }

      context "when it is unique in scope of organization" do
        it "does not add an error" do
          expect(errors.where(:webhook_url, :taken)).not_to be_present
        end
      end

      context "when it not is unique in scope of organization" do
        subject(:webhook_endpoint) do
          build(:webhook_endpoint, organization:, webhook_url: organization.webhook_endpoints.first.webhook_url)
        end

        let(:organization) { create(:organization) }
        let(:errors) { webhook_endpoint.errors }

        before { webhook_endpoint.valid? }

        it "adds an error" do
          expect(errors.where(:webhook_url, :taken)).to be_present
        end
      end
    end

    context "when http webhook url is valid" do
      before { webhook_endpoint.webhook_url = "http://foo.bar" }

      it "is valid" do
        expect(webhook_endpoint).to be_valid
      end
    end

    context "when https webhook url is valid" do
      before { webhook_endpoint.webhook_url = "https://foo.bar" }

      it "is valid" do
        expect(webhook_endpoint).to be_valid
      end
    end

    context "when webhook url is invalid" do
      before { webhook_endpoint.webhook_url = "foobar" }

      it "is invalid" do
        expect(webhook_endpoint).not_to be_valid
      end
    end

    describe "event_type validity" do
      context "when nil" do
        before { webhook_endpoint.event_types = nil }

        it "is valid" do
          expect(webhook_endpoint).to be_valid
        end
      end

      context "when an empty array" do
        before { webhook_endpoint.event_types = [] }

        it "is valid" do
          expect(webhook_endpoint).to be_valid
        end
      end

      context "when not an array" do
        before { webhook_endpoint.event_types = "not_an_array" }

        it "is not valid" do
          expect(webhook_endpoint).not_to be_valid
        end
      end

      context "when contains valid types" do
        before { webhook_endpoint.event_types = ["customer.updated"] }

        it "is valid" do
          expect(webhook_endpoint).to be_valid
        end
      end

      context "when contains invalid types" do
        before { webhook_endpoint.event_types = ["invalid.event"] }

        it "is not valid" do
          expect(webhook_endpoint).not_to be_valid
        end
      end
    end
  end

  describe "callbacks" do
    describe "#normalize_event_types" do
      subject(:webhook_endpoint) { build(:webhook_endpoint, event_types:) }

      context "when event_types contains duplicates, blanks, mixed case and whitespaces" do
        let(:event_types) {
          [
            " Customer.Created ",
            "invoice.drafted ",
            " Invoice.DRAFTED",
            nil,
            "  ",
            ""
          ]
        }

        it "normalizes the event types" do
          webhook_endpoint.valid?
          expect(webhook_endpoint).to be_valid
          expect(webhook_endpoint.event_types).to eq(["customer.created", "invoice.drafted"])
        end
      end

      context "when event_types is nil" do
        let(:event_types) { nil }

        it "does not change event_types" do
          webhook_endpoint.valid?
          expect(webhook_endpoint).to be_valid
          expect(webhook_endpoint.event_types).to be_nil
        end
      end

      context "when event_types contains *" do
        let(:event_types) { ["*"] }

        it "sets event_types to nil" do
          webhook_endpoint.valid?
          expect(webhook_endpoint).to be_valid
          expect(webhook_endpoint.event_types).to be_nil
        end
      end

      context "when event_types contains * and other values" do
        let(:event_types) { ["*", "customer.created"] }

        it "does not change event_types" do
          webhook_endpoint.valid?
          expect(webhook_endpoint).not_to be_valid
          expect(webhook_endpoint.event_types).to eq(["*", "customer.created"])
        end
      end
    end
  end

  describe "constants" do
    describe "WEBHOOK_EVENT_TYPES" do
      it "matches SendWebhookJob::WEBHOOK_SERVICES" do
        expect(WebhookEndpoint::WEBHOOK_EVENT_TYPES).to match_array(SendWebhookJob::WEBHOOK_SERVICES.keys.map(&:to_s))
      end
    end
  end
end
