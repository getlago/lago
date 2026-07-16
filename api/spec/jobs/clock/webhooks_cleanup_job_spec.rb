# frozen_string_literal: true

require "rails_helper"

describe Clock::WebhooksCleanupJob do
  subject(:webhooks_cleanup_job) { described_class }

  it_behaves_like "a unique job" do
    let(:job_args) { [] }
  end

  def with_batch_size(size)
    previous = described_class.batch_size
    described_class.batch_size = size
    yield
  ensure
    described_class.batch_size = previous
  end

  def with_retention_period(period)
    previous = described_class.retention_period
    described_class.retention_period = period
    yield
  ensure
    described_class.retention_period = previous
  end

  describe ".perform" do
    context "when webhooks are older than the retention period" do
      it "removes them" do
        create(:webhook, :succeeded, updated_at: 100.days.ago)

        expect { webhooks_cleanup_job.perform_now }
          .to change(Webhook, :count).to(0)
      end
    end

    context "when webhooks are newer than the retention period" do
      it "does not delete them" do
        create(:webhook, updated_at: 89.days.ago)

        expect { webhooks_cleanup_job.perform_now }
          .not_to change(Webhook, :count)
      end
    end

    context "when there are more webhooks than the batch size" do
      around { |test| with_batch_size(2, &test) }

      it "processes multiple batches" do
        create_list(:webhook, 3, :succeeded, updated_at: 100.days.ago)
        recent = create(:webhook, updated_at: 89.days.ago)

        expect { webhooks_cleanup_job.perform_now }
          .to change(Webhook, :count).to(1)

        expect(Webhook.first).to eq(recent)
      end
    end

    context "with a custom retention period" do
      around { |test| with_retention_period(30.days, &test) }

      it "uses the configured retention period" do
        create(:webhook, updated_at: 31.days.ago)
        create(:webhook, updated_at: 29.days.ago)

        expect { webhooks_cleanup_job.perform_now }
          .to change(Webhook, :count).to(1)
      end
    end
  end
end
