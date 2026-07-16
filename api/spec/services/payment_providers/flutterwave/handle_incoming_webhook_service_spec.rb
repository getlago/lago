# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Flutterwave::HandleIncomingWebhookService do
  subject(:webhook_service) { described_class.new(organization_id:, body:, secret:, code:) }

  let(:organization) { create(:organization) }
  let(:organization_id) { organization.id }
  let(:flutterwave_provider) { create(:flutterwave_provider, organization:, webhook_secret:) }
  let(:webhook_secret) { "webhook_secret_hash" }
  let(:code) { flutterwave_provider.code }
  let(:body) { payload.to_json }
  let(:secret) { webhook_secret }

  let(:payload) do
    {
      event: "charge.completed",
      data: {
        id: 123456,
        status: "successful",
        amount: 100.0,
        currency: "USD",
        customer: {
          id: 789,
          email: "customer@example.com"
        },
        tx_ref: "lago_invoice_12345",
        meta: {
          lago_invoice_id: "12345",
          lago_payable_type: "Invoice"
        }
      }
    }
  end

  describe "#call" do
    context "when secret is valid" do
      it "enqueues the webhook processing job" do
        expect { webhook_service.call }.to have_enqueued_job(PaymentProviders::Flutterwave::HandleEventJob)
      end

      it "returns success result" do
        result = webhook_service.call
        expect(result).to be_success
        expect(result.event).to eq(body)
      end
    end

    context "when secret is invalid" do
      let(:secret) { "invalid_secret" }

      it "returns service failure" do
        result = webhook_service.call
        expect(result).not_to be_success
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.message).to eq("webhook_error: Invalid webhook secret")
      end
    end

    context "when webhook secret is missing" do
      let(:webhook_secret) { nil }
      let(:secret) { nil }

      before do
        secrets = JSON.parse(flutterwave_provider.secrets || "{}")
        secrets.delete("webhook_secret")
        flutterwave_provider.update!(secrets: secrets.to_json)
      end

      it "returns service failure" do
        result = webhook_service.call
        expect(result).not_to be_success
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.message).to eq("webhook_error: Webhook secret is missing")
      end
    end

    context "when payment provider is not found" do
      let(:code) { "non_existent_code" }

      it "returns service failure" do
        result = webhook_service.call
        expect(result).not_to be_success
      end
    end
  end
end
