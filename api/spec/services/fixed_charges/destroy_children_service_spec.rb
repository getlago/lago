# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::DestroyChildrenService do
  subject(:destroy_service) { described_class.new(fixed_charge) }

  let(:organization) { create(:organization) }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:fixed_charge) { create(:fixed_charge, :deleted, plan:, add_on:) }

  let(:child_plan) { create(:plan, organization:, parent: plan) }
  let(:subscription) { create(:subscription, plan: child_plan) }
  let(:child_fixed_charge) do
    create(
      :fixed_charge,
      plan: child_plan,
      add_on:,
      parent: fixed_charge,
      properties: {amount: "100"}
    )
  end

  before do
    child_fixed_charge
    subscription
  end

  describe "#call" do
    it "soft deletes the child fixed charge" do
      freeze_time do
        expect { destroy_service.call }.to change(FixedCharge, :count).by(-1)
          .and change { child_fixed_charge.reload.deleted_at }.from(nil).to(Time.current)
      end
    end

    it "does not touch plan" do
      freeze_time do
        expect { destroy_service.call }.not_to change { child_plan.reload.updated_at }
      end
    end

    it "returns success with the fixed charge" do
      result = destroy_service.call

      expect(result).to be_success
      expect(result.fixed_charge).to eq(fixed_charge)
    end

    context "when fixed charge is not found" do
      let(:fixed_charge) { nil }
      let(:child_fixed_charge) { nil }

      it "returns an empty result" do
        result = destroy_service.call

        expect(result).to be_success
        expect(result.fixed_charge).to be_nil
      end
    end

    context "when fixed charge is not deleted" do
      let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }

      it "returns an empty result" do
        result = destroy_service.call

        expect(result).to be_success
        expect(result.fixed_charge).to be_nil
      end
    end

    context "when subscription is terminated" do
      let(:subscription) { create(:subscription, plan: child_plan, status: :terminated) }

      it "does not delete the child fixed charge" do
        expect { destroy_service.call }.not_to change(FixedCharge, :count)
      end
    end
  end
end
