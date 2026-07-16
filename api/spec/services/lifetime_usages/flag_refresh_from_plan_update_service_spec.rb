# frozen_string_literal: true

require "rails_helper"

RSpec.describe LifetimeUsages::FlagRefreshFromPlanUpdateService do
  subject { described_class.call(plan:) }

  let(:plan) { create(:plan) }
  let(:result) { subject }

  describe "#call" do
    context "when plan has no active subscriptions" do
      it "returns zero for updated lifetime usages" do
        expect(result.updated_lifetime_usages).to eq(0)
      end
    end

    context "when plan has active subscriptions with lifetime usages" do
      let(:active_subscription1) { create(:subscription, :active, plan: plan) }
      let(:active_subscription2) { create(:subscription, :active, plan: plan) }
      let(:terminated_subscription) { create(:subscription, :terminated, plan: plan) }

      let(:lifetime_usage1) { create(:lifetime_usage, subscription: active_subscription1) }
      let(:lifetime_usage2) { create(:lifetime_usage, subscription: active_subscription2) }
      let(:lifetime_usage3) { create(:lifetime_usage, subscription: terminated_subscription) }

      before do
        lifetime_usage1
        lifetime_usage2
        lifetime_usage3
      end

      it "flags only lifetime usages of active subscriptions for recalculation" do
        expect(result.updated_lifetime_usages).to eq(2)

        expect(lifetime_usage1.reload.recalculate_invoiced_usage).to be_truthy
        expect(lifetime_usage2.reload.recalculate_invoiced_usage).to be_truthy
        expect(lifetime_usage3.reload.recalculate_invoiced_usage).to be_falsey
      end
    end

    context "when plan has active subscriptions but no lifetime usages" do
      before do
        create(:subscription, :active, plan: plan)
        create(:subscription, :active, plan: plan)
      end

      it "returns zero for updated lifetime usages" do
        expect(result.updated_lifetime_usages).to eq(0)
      end
    end

    context "when there are lifetime usages for other plans" do
      let(:other_plan) { create(:plan) }
      let(:other_subscription) { create(:subscription, :active, plan: other_plan) }
      let(:current_subscription) { create(:subscription, :active, plan: plan) }

      let(:other_lifetime_usage) { create(:lifetime_usage, subscription: other_subscription) }
      let(:current_lifetime_usage) { create(:lifetime_usage, subscription: current_subscription) }

      before do
        other_lifetime_usage
        current_lifetime_usage
      end

      it "only flags lifetime usages for the given plan" do
        expect(result.updated_lifetime_usages).to eq(1)

        expect(current_lifetime_usage.reload.recalculate_invoiced_usage).to be_truthy
        expect(other_lifetime_usage.reload.recalculate_invoiced_usage).to be_falsey
      end
    end
  end
end
