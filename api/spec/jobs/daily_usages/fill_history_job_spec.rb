# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyUsages::FillHistoryJob do
  let(:subscription) { create(:subscription) }
  let(:from_date) { Time.current.beginning_of_month }
  let(:to_date) { from_date.end_of_month }

  let(:result) { DailyUsages::FillHistoryService::Result.new }

  it_behaves_like "a configurable queue", "analytics_low_priority", "SIDEKIQ_ANALYTICS", "long_running" do
    let(:arguments) { {subscription:, from_date:, to_date:} }
  end

  describe ".perform" do
    it "delegates its logic to the DailyUsages::FillHistoryService" do
      allow(DailyUsages::FillHistoryService).to receive(:call)
        .with(subscription:, from_date:, to_date:, sandbox: false)
        .and_return(result)

      described_class.perform_now(subscription:, from_date:, to_date:)

      expect(DailyUsages::FillHistoryService).to have_received(:call)
        .with(subscription:, from_date:, to_date:, sandbox: false).once
    end
  end

  describe "retry_on" do
    context "when the error message is 'Response: end of file reached'" do
      before do
        allow(DailyUsages::FillHistoryService).to receive(:call!)
          .and_raise(ActiveRecord::ActiveRecordError.new("Response: end of file reached"))
      end

      it "retries the job" do
        assert_performed_jobs(6, only: [described_class]) do
          expect do
            described_class.perform_later(subscription:, from_date:, to_date:)
          end.to raise_error(DailyUsages::RetryableError)
        end
      end
    end

    context "when the error message is different" do
      before do
        allow(DailyUsages::FillHistoryService).to receive(:call!)
          .and_raise(ActiveRecord::ActiveRecordError.new("some other error"))
      end

      it "does not retry the job" do
        assert_performed_jobs(1, only: [described_class]) do
          expect do
            described_class.perform_later(subscription:, from_date:, to_date:)
          end.to raise_error(ActiveRecord::ActiveRecordError)
        end
      end
    end
  end
end
