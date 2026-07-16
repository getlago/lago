# frozen_string_literal: true

require "rails_helper"

RSpec.describe Charges::DestroyChildrenService do
  subject(:destroy_service) { described_class.new(charge) }

  let(:billable_metric) { create(:billable_metric) }
  let(:organization) { billable_metric.organization }
  let(:plan) { create(:plan, organization:) }
  let(:charge) { create(:standard_charge, :deleted, plan:, billable_metric:) }

  let(:child_plan) { create(:plan, organization:, parent_id:) }
  let(:parent_id) { plan.id }
  let(:charge_parent_id) { charge.id }
  let(:subscription) { create(:subscription, plan: child_plan) }
  let(:child_charge) do
    create(
      :standard_charge,
      plan_id: child_plan.id,
      parent_id: charge_parent_id,
      billable_metric_id: billable_metric.id,
      properties: {amount: "300"}
    )
  end

  before do
    child_charge
    subscription
  end

  describe "#call" do
    it "soft deletes the charge" do
      freeze_time do
        expect { destroy_service.call }.to change(Charge, :count).by(-1)
          .and change { child_charge.reload.deleted_at }.from(nil).to(Time.current)
      end
    end

    it "does not touch plan" do
      freeze_time do
        expect { destroy_service.call }.not_to change { child_plan.reload.updated_at }
      end
    end

    context "when charge is not found" do
      let(:charge) { nil }
      let(:child_charge) { nil }

      it "returns an empty result" do
        result = destroy_service.call

        expect(result).to be_success
        expect(result.charge).to be_nil
      end
    end

    context "when charge is not deleted" do
      let(:charge) { create(:standard_charge, plan:, billable_metric:) }

      it "returns an empty result" do
        result = destroy_service.call

        expect(result).to be_success
        expect(result.charge).to be_nil
      end
    end
  end
end
