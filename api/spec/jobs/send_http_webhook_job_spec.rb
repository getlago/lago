# frozen_string_literal: true

require "rails_helper"
require "aws-sdk-s3"

RSpec.describe SendHttpWebhookJob do
  subject(:send_http_webhook_job) { described_class }

  let(:webhook) { create(:webhook) }

  describe "#perform" do
    before { allow(Webhooks::SendHttpService).to receive(:call) }

    it "calls the send http webhook service" do
      send_http_webhook_job.perform_now(webhook)

      expect(Webhooks::SendHttpService).to have_received(:call).with(webhook:)
    end

    context "when S3 throttles the payload storage" do
      let(:slow_down_error) { Aws::S3::Errors::SlowDown.new(nil, "Please reduce your request rate.") }

      before { allow(Webhooks::SendHttpService).to receive(:call).and_raise(slow_down_error) }

      it "retries the job instead of failing" do
        expect { send_http_webhook_job.perform_now(webhook) }
          .to have_enqueued_job(described_class).with(webhook)
      end

      it "does not increment the webhook retries counter" do
        expect { send_http_webhook_job.perform_now(webhook) }
          .not_to change { webhook.reload.retries }
      end
    end
  end
end
