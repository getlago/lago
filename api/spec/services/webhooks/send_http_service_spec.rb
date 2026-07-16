# frozen_string_literal: true

require "rails_helper"
require "aws-sdk-s3"

RSpec.describe Webhooks::SendHttpService do
  subject(:service) { described_class.new(webhook:) }

  let(:webhook_endpoint) { create(:webhook_endpoint, webhook_url: "https://wh.test.com") }
  let(:webhook) { create(:webhook, webhook_endpoint:) }
  let(:lago_client) { instance_double(LagoHttpClient::Client) }

  around do |example|
    original_value = ENV["LAGO_WEBHOOK_ATTEMPTS"]
    ENV["LAGO_WEBHOOK_ATTEMPTS"] = "3"
    example.run
  ensure
    ENV["LAGO_WEBHOOK_ATTEMPTS"] = original_value
  end

  context "when client returns a success" do
    before do
      WebMock.stub_request(:post, "https://wh.test.com").to_return(status: 200, body: "ok")
    end

    it "marks the webhook as succeeded" do
      service.call

      expect(WebMock).to have_requested(:post, "https://wh.test.com").with(
        body: webhook.payload.to_json,
        headers: {"Content-Type" => "application/json"}
      )
      expect(webhook.status).to eq "succeeded"
      expect(webhook.http_status).to eq 200
      expect(webhook.response).to eq "ok"
      expect(webhook.response_key).to match(%r{/response\.json\.gz\z})
      expect(webhook.read_attribute(:response)).to be_nil
    end
  end

  context "when client returns an error" do
    let(:error_body) do
      {
        message: "forbidden"
      }
    end
    let(:expected_timeout_seconds) { 30 }

    before do
      allow(LagoHttpClient::Client).to receive(:new)
        .with(webhook.webhook_endpoint.webhook_url, read_timeout: expected_timeout_seconds, write_timeout: expected_timeout_seconds, open_timeout: expected_timeout_seconds)
        .and_return(lago_client)
      allow(lago_client).to receive(:post_with_response).and_raise(
        LagoHttpClient::HttpError.new(403, error_body.to_json, "")
      )
      allow(SendHttpWebhookJob).to receive(:set).and_return(class_double(SendHttpWebhookJob, perform_later: nil))
    end

    context "when LAGO_WEBHOOK_TIMEOUT_SECONDS is set" do
      let(:expected_timeout_seconds) { 45 }

      around do |example|
        original_value = ENV["LAGO_WEBHOOK_TIMEOUT_SECONDS"]
        ENV["LAGO_WEBHOOK_TIMEOUT_SECONDS"] = "45"
        example.run
      ensure
        ENV["LAGO_WEBHOOK_TIMEOUT_SECONDS"] = original_value
      end

      it "uses the configured timeout" do
        service.call

        expect(LagoHttpClient::Client).to have_received(:new)
          .with(webhook.webhook_endpoint.webhook_url, read_timeout: expected_timeout_seconds, write_timeout: expected_timeout_seconds, open_timeout: expected_timeout_seconds)
      end
    end

    it "creates a retrying webhook" do
      service.call

      expect(webhook).to be_retrying
      expect(webhook.http_status).to eq(403)
      expect(SendHttpWebhookJob).to have_received(:set)
    end

    context "with a retrying webhook" do
      let(:webhook) { create(:webhook, :retrying, retries: 1) }

      it "fails the retried webhooks" do
        service.call

        expect(webhook).to be_retrying
        expect(webhook.http_status).to eq(403)
        expect(webhook.retries).to eq(2)
        expect(webhook.last_retried_at).not_to be_nil
        expect(SendHttpWebhookJob).to have_received(:set)
      end

      context "when the webhook failed 3 times" do
        let(:webhook) { create(:webhook, :retrying, retries: 2) }

        it "stops trying and marks the webhook as failed" do
          service.call

          expect(webhook).to be_failed
          expect(webhook.http_status).to eq(403)
          expect(webhook.reload.retries).to eq 3
          expect(SendHttpWebhookJob).not_to have_received(:set)
        end
      end
    end
  end

  context "when S3 throttles reading the stored payload" do
    let(:webhook) { create(:webhook, :retrying, retries: 1) }
    let(:slow_down_error) { Aws::S3::Errors::SlowDown.new(nil, "Please reduce your request rate.") }

    before do
      allow(webhook).to receive(:payload).and_raise(slow_down_error)
      allow(SendHttpWebhookJob).to receive(:set)
    end

    it "lets the error propagate for the job to retry" do
      expect { service.call }.to raise_error(Aws::S3::Errors::SlowDown)
    end

    it "does not count the S3 error against the webhook retry counter" do
      expect { service.call }.to raise_error(Aws::S3::Errors::SlowDown)

      expect(webhook.retries).to eq(1)
      expect(webhook).to be_retrying
      expect(SendHttpWebhookJob).not_to have_received(:set)
    end
  end
end
