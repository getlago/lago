# frozen_string_literal: true

require "rails_helper"

RSpec.describe Plans::UpdateUsageThresholdsService do
  subject { described_class.call(plan:, usage_thresholds_params:) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }

  before do
    allow(LifetimeUsages::FlagRefreshFromPlanUpdateJob).to receive(:perform_after_commit)
  end

  context "when usage_thresholds_params is empty" do
    let(:usage_thresholds_params) { [] }

    context "when progressive_billing is not enabled" do
      it "does not update the plan" do
        expect(subject.plan.usage_thresholds).to be_empty
      end
    end

    context "when progressive_billing is enabled" do
      around { |test| premium_integration!(organization, "progressive_billing", &test) }

      it "does not update the plan" do
        expect(subject.plan.usage_thresholds).to be_empty
        expect(LifetimeUsages::FlagRefreshFromPlanUpdateJob).not_to have_received(:perform_after_commit)
      end
    end
  end

  context "when usage_thresholds_params is not empty" do
    let(:usage_thresholds_params) do
      [
        {
          threshold_display_name: "Threshold 1",
          amount_cents: 1000
        }
      ]
    end

    context "when progressive_billing is not enabled" do
      it "does not update the plan" do
        expect(subject.plan.usage_thresholds).to be_empty
        expect(LifetimeUsages::FlagRefreshFromPlanUpdateJob).not_to have_received(:perform_after_commit).with(plan)
      end
    end

    context "when progressive_billing is enabled" do
      around { |test| premium_integration!(organization, "progressive_billing", &test) }

      it "does update the plan" do
        thresholds = subject.plan.usage_thresholds
        expect(thresholds.size).to eq(1)
        expect(thresholds.first.threshold_display_name).to eq("Threshold 1")
        expect(thresholds.first.amount_cents).to eq(1000)
        expect(LifetimeUsages::FlagRefreshFromPlanUpdateJob).to have_received(:perform_after_commit)
      end
    end
  end

  context "when plan already has usage_thresholds" do
    let(:threshold1) do
      create(:usage_threshold, plan:, threshold_display_name: "Threshold 1", amount_cents: 1)
    end

    let(:threshold2) do
      create(:usage_threshold, plan:, threshold_display_name: "Threshold 2", amount_cents: 2)
    end

    before do
      threshold1
      threshold2
    end

    context "when usage_thresholds_params is empty" do
      let(:usage_thresholds_params) { [] }

      context "when progressive_billing is not enabled" do
        it "does not update the plan" do
          expect { subject }.not_to change(plan, :usage_thresholds)
        end
      end

      context "when progressive_billing is enabled" do
        around { |test| premium_integration!(organization, "progressive_billing", &test) }

        it "clears the thresholds" do
          expect(subject.plan.usage_thresholds).to be_empty
          expect(LifetimeUsages::FlagRefreshFromPlanUpdateJob).not_to have_received(:perform_after_commit)
        end
      end
    end

    context "when usage_thresholds_params is not empty" do
      let(:usage_thresholds_params) do
        [
          {
            threshold_display_name: "Other threshold",
            amount_cents: 1000
          }
        ]
      end

      context "when progressive_billing is not enabled" do
        it "does not update the plan" do
          expect { subject }.not_to change(plan, :usage_thresholds)
        end
      end

      context "when progressive_billing is enabled" do
        around { |test| premium_integration!(organization, "progressive_billing", &test) }

        it "does update the plan" do
          thresholds = subject.plan.usage_thresholds
          expect(thresholds.size).to eq(1)
          expect(thresholds.first.threshold_display_name).to eq("Other threshold")
          expect(thresholds.first.amount_cents).to eq(1000)
          expect(LifetimeUsages::FlagRefreshFromPlanUpdateJob).to have_received(:perform_after_commit).with(plan)
        end
      end
    end
  end
end
