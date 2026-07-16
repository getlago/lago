# frozen_string_literal: true

require "rails_helper"

describe Clock::InboundWebhooksCleanupJob, job: true do
  subject(:inbound_webhooks_cleanup_job) { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  describe ".perform" do
    it "removes all old inbound webhooks" do
      create(:inbound_webhook, updated_at: 90.days.ago)

      expect { inbound_webhooks_cleanup_job.perform_now }
        .to change(InboundWebhook, :count).to(0)
    end

    it "does not delete recent inbound webhooks" do
      create(:inbound_webhook, updated_at: 89.days.ago)

      expect { inbound_webhooks_cleanup_job.perform_now }
        .not_to change(InboundWebhook, :count)
    end
  end
end
