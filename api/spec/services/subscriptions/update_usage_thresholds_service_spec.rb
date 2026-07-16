# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::UpdateUsageThresholdsService, :premium do
  subject(:service) { described_class.new(subscription:, usage_thresholds_params:, partial:) }

  let(:organization) { create(:organization, premium_integrations:) }
  let(:premium_integrations) { ["progressive_billing"] }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:subscription) { create(:subscription, customer:, plan:, organization:) }
  let(:lifetime_usage) { create(:lifetime_usage, subscription:, organization:) }
  let(:usage_thresholds_params) { [{amount_cents: 1000, threshold_display_name: "Test"}] }
  let(:partial) { false }

  before do
    lifetime_usage
    allow(UsageThresholds::UpdateService).to receive(:call!).and_return(BaseResult.new)
  end

  describe "#call" do
    context "when progressive_billing is not enabled" do
      let(:premium_integrations) { [] }

      it "returns early without calling UsageThresholds::UpdateService" do
        result = service.call

        expect(result).to be_success
        expect(UsageThresholds::UpdateService).not_to have_received(:call!)
      end
    end

    context "when progressive_billing is enabled" do
      it "calls UsageThresholds::UpdateService with correct arguments" do
        service.call

        expect(UsageThresholds::UpdateService).to have_received(:call!).with(
          model: subscription,
          usage_thresholds_params:,
          partial:
        )
      end

      context "when partial is true" do
        let(:partial) { true }

        it "passes partial: true to UsageThresholds::UpdateService" do
          service.call

          expect(UsageThresholds::UpdateService).to have_received(:call!).with(
            model: subscription,
            usage_thresholds_params:,
            partial: true
          )
        end
      end

      context "when plan is a child plan (override)" do
        let(:parent_plan) { create(:plan, organization:) }
        let(:plan) { create(:plan, organization:, parent: parent_plan) }
        let!(:plan_usage_threshold) { create(:usage_threshold, plan:, organization:) }

        it "soft deletes usage thresholds attached to the plan override" do
          expect { service.call }.to change { plan_usage_threshold.reload.deleted_at }.from(nil)
        end
      end

      context "when plan is not a child plan" do
        let!(:plan_usage_threshold) { create(:usage_threshold, plan:, organization:) }

        it "does not delete usage thresholds attached to the plan" do
          expect { service.call }.not_to change { plan_usage_threshold.reload.deleted_at }
        end
      end

      context "when subscription has usage thresholds after update" do
        before { create(:usage_threshold, :for_subscription, subscription:, organization:) }

        it "updates lifetime_usage recalculate_invoiced_usage to true" do
          expect { service.call }.to change { lifetime_usage.reload.recalculate_invoiced_usage }.to(true)
        end
      end

      context "when subscription has no usage thresholds after update" do
        it "does not update lifetime_usage" do
          expect { service.call }.not_to change { lifetime_usage.reload.recalculate_invoiced_usage }
        end
      end

      context "when UsageThresholds::UpdateService fails" do
        let(:failed_result) { BaseResult.new.tap { |r| r.single_validation_failure!(error_code: "error", field: :test) } }

        before do
          allow(UsageThresholds::UpdateService).to receive(:call!).and_raise(BaseService::FailedResult.new(failed_result, "error"))
        end

        it "returns the failed result" do
          result = service.call

          expect(result).not_to be_success
          expect(result.error.messages[:test]).to include("error")
        end
      end
    end
  end
end
