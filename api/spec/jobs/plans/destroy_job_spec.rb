# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plans::DestroyJob do
  include ActiveJob::TestHelper

  let(:plan) { create(:plan) }
  let(:child_plan) { create(:plan, parent: plan) }
  let(:service_result) { BaseService::Result.new }

  before do
    plan.children << child_plan
  end

  describe "unique job behavior" do
    around do |example|
      ActiveJob::Uniqueness.reset_manager!
      example.run
      ActiveJob::Uniqueness.test_mode!
    end

    it "does not enqueue duplicate jobs" do
      expect do
        described_class.perform_later(plan)
        described_class.perform_later(plan)
      end.to change { enqueued_jobs.count }.by(1) # rubocop:disable RSpec/ExpectChange
    end
  end

  describe "#perform" do
    before do
      allow(Plans::DestroyService).to receive(:call).and_return(service_result)
    end

    context "when destroy service succeeds" do
      let(:service_result) { BaseService::Result.new }

      it "calls the destroy service for child plans first" do
        described_class.perform_now(plan)

        expect(Plans::DestroyService)
          .to have_received(:call)
          .with(plan: child_plan)
          .ordered

        expect(Plans::DestroyService)
          .to have_received(:call)
          .with(plan: plan)
          .ordered
      end
    end

    context "when destroy service fails" do
      let(:service_result) do
        BaseService::Result.new.service_failure!(
          code: "failure",
          message: "Destroy failed"
        )
      end

      it "raises an error when the destroy service fails" do
        expect { described_class.perform_now(plan) }
          .to raise_error(BaseService::ServiceFailure, "failure: Destroy failed")
      end
    end
  end
end
