# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Cashfree::HandleIncomingWebhookService do
  let(:webhook_service) { described_class.new(organization_id:, body:, code:, timestamp:, signature:) }

  let(:organization) { create(:organization) }
  let(:organization_id) { organization.id }
  let(:cashfree_provider) { create(:cashfree_provider, organization:, client_secret:) }
  let(:client_secret) { "cfsk_ma_prod_abc_123456" }
  let(:code) { nil }
  let(:timestamp) { "1629271506" }
  let(:signature) { "MFB3Rkubs4jB97ROS/I4iu9llAAP5ykJ3GZYp95o/Mw=" }

  let(:body) do
    path = Rails.root.join("spec/fixtures/cashfree/payment_link_event_payment.json")
    JSON.parse(File.read(path)).to_json # NOTE: Ensure valid sha256 signature
  end

  before { cashfree_provider }

  describe "#call" do
    it "checks the webhook" do
      result = webhook_service.call

      expect(result).to be_success

      expect(PaymentProviders::Cashfree::HandleEventJob).to have_been_enqueued
    end

    context "when failing to validate the signature" do
      let(:signature) { "signature" }

      it "returns an error" do
        result = webhook_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("webhook_error")
        expect(result.error.error_message).to eq("Invalid signature")
      end
    end
  end
end
