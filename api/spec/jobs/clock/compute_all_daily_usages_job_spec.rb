# frozen_string_literal: true

require "rails_helper"

RSpec.describe Clock::ComputeAllDailyUsagesJob do
  subject(:compute_job) { described_class }

  describe "unique job behavior" do
    around do |example|
      ActiveJob::Uniqueness.reset_manager!
      example.run
      ActiveJob::Uniqueness.test_mode!
    end

    it "does not enqueue duplicate jobs" do
      expect do
        described_class.perform_later
        described_class.perform_later
      end.to change { enqueued_jobs.count }.by(1) # rubocop:disable RSpec/ExpectChange
    end
  end

  describe ".perform" do
    before { allow(DailyUsages::ComputeAllService).to receive(:call) }

    it "calls DailyUsages::ComputeAllService" do
      freeze_time do
        compute_job.perform_now
        expect(DailyUsages::ComputeAllService).to have_received(:call).with(timestamp: Time.current)
      end
    end
  end
end
