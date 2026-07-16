# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::RetryService do
  subject(:retry_service) { described_class.new(webhook:) }

  let(:webhook) { create(:webhook, :failed) }

  it "enqueues a SendWebhookJob" do
    expect { retry_service.call }.to have_enqueued_job(SendHttpWebhookJob).with(webhook)
  end

  it "assigns webhook to result" do
    result = retry_service.call

    expect(result.webhook.id).to eq(webhook.id)
  end

  context "when webhook is not found" do
    let(:webhook) { nil }

    it "returns an error" do
      result = retry_service.call

      expect(result).not_to be_success
      expect(result.error.error_code).to eq("webhook_not_found")
    end
  end

  context "when webhook is succeeded" do
    let(:webhook) { create(:webhook, :succeeded) }

    it "returns an error" do
      result = retry_service.call

      expect(result).not_to be_success
      expect(result.error.code).to eq("is_succeeded")
    end
  end
end
