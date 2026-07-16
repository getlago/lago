# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequests::Payments::DeliverErrorWebhookService do
  subject(:webhook_service) { described_class.new(payment_request, params) }

  let(:payment_request) { create(:payment_request) }
  let(:params) do
    {
      "provider_customer_id" => "customer",
      "provider_error" => {
        "error_message" => "message",
        "error_code" => "code"
      }
    }.with_indifferent_access
  end

  describe ".call_async" do
    it "enqueues a job to send an payment request payment failure webhook" do
      expect do
        webhook_service.call_async
      end.to have_enqueued_job(SendWebhookJob).with("payment_request.payment_failure", payment_request, params)
    end
  end
end
