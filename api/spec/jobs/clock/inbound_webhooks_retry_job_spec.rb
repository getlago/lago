# frozen_string_literal: true

require "rails_helper"

describe Clock::InboundWebhooksRetryJob, job: true do
  subject(:inbound_webhooks_retry_job) { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    before { inbound_webhook }

    context "when inbound webhook is pending" do
      let(:inbound_webhook) { create :inbound_webhook, status:, created_at: }
      let(:status) { "pending" }
      let(:created_at) { 119.minutes.ago }

      it "does not queue a job" do
        inbound_webhooks_retry_job.perform_now

        expect(InboundWebhooks::ProcessJob).not_to have_been_enqueued
      end

      context "when inbound webhook was created more than 2 hours ago" do
        let(:created_at) { 121.hours.ago }

        it "queues a job to process the inbound webhook" do
          inbound_webhooks_retry_job.perform_now

          expect(InboundWebhooks::ProcessJob)
            .to have_been_enqueued
            .with(inbound_webhook: inbound_webhook)
        end
      end
    end

    context "when inbound webhook is processing" do
      let(:inbound_webhook) { create :inbound_webhook, status:, processing_at: }
      let(:status) { "processing" }
      let(:processing_at) { 119.minutes.ago }

      it "does not queue a job" do
        inbound_webhooks_retry_job.perform_now

        expect(InboundWebhooks::ProcessJob).not_to have_been_enqueued
      end

      context "when inbound webhook started processing more than 2 hours ago" do
        let(:processing_at) { 121.minutes.ago }

        it "queues a job to process the inbound webhook" do
          inbound_webhooks_retry_job.perform_now

          expect(InboundWebhooks::ProcessJob)
            .to have_been_enqueued
            .with(inbound_webhook: inbound_webhook)
        end
      end
    end

    context "when inbound webhook is failed" do
      let(:inbound_webhook) { create :inbound_webhook, status: }
      let(:status) { "failed" }

      it "does not queue a job" do
        inbound_webhooks_retry_job.perform_now

        expect(InboundWebhooks::ProcessJob).not_to have_been_enqueued
      end
    end

    context "when inbound webhook is processed" do
      let(:inbound_webhook) { create :inbound_webhook, status: }
      let(:status) { "succeeded" }

      it "does not queue a job" do
        inbound_webhooks_retry_job.perform_now

        expect(InboundWebhooks::ProcessJob).not_to have_been_enqueued
      end
    end
  end
end
