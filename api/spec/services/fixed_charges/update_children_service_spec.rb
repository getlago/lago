# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::UpdateChildrenService do
  subject(:update_service) do
    described_class.new(
      fixed_charge:,
      params:,
      old_parent_attrs:,
      child_ids:
    )
  end

  let(:organization) { create(:organization) }
  let(:add_on) { create(:add_on, organization:) }
  let(:plan) { create(:plan, organization:) }
  let(:old_parent_attrs) { fixed_charge&.attributes }
  let(:fixed_charge) do
    create(
      :fixed_charge,
      plan:,
      add_on:,
      properties: {amount: "300"},
      units: 10
    )
  end

  let(:child_plan) { create(:plan, organization:, parent_id: plan.id) }
  let(:child_fixed_charge) do
    create(
      :fixed_charge,
      plan: child_plan,
      add_on:,
      parent_id: fixed_charge.id,
      properties: {amount: "300"},
      units: 10
    )
  end
  let(:child_ids) { [child_fixed_charge&.id] }
  let(:params) do
    {
      charge_model: "standard",
      properties: {amount: "400"},
      units: 20
    }
  end

  describe "#call" do
    context "when fixed_charge is not found" do
      let(:fixed_charge) { nil }
      let(:child_fixed_charge) { nil }

      it "returns an empty result" do
        result = update_service.call

        expect(result).to be_success
        expect(result.fixed_charge).to be_nil
      end
    end

    context "when fixed_charge has children that have not been modified" do
      it "updates child fixed charge" do
        update_service.call

        expect(child_fixed_charge.reload).to have_attributes(
          properties: {"amount" => "400"},
          units: 20
        )
      end

      it "does not touch plan" do
        freeze_time do
          expect { update_service.call }.not_to change { child_plan.reload.updated_at }
        end
      end
    end

    context "when fixed_charge has children that have been modified" do
      let(:child_fixed_charge) do
        create(
          :fixed_charge,
          plan: child_plan,
          add_on:,
          parent_id: fixed_charge.id,
          properties: {amount: "500"},
          units: 15
        )
      end

      it "does not update fixed charge properties" do
        update_service.call

        expect(child_fixed_charge.reload).to have_attributes(
          properties: {"amount" => "500"},
          units: 15
        )
      end
    end

    context "when fixed_charge has no children" do
      let(:child_fixed_charge) do
        create(
          :fixed_charge,
          plan: child_plan,
          add_on:,
          parent_id: nil,
          properties: {amount: "300"},
          units: 10
        )
      end

      before do
        allow(FixedCharges::UpdateService).to receive(:call!).and_call_original
      end

      it "does not call the update service" do
        update_service.call

        expect(FixedCharges::UpdateService).not_to have_received(:call!)
      end

      it "does not update fixed charge properties" do
        update_service.call

        expect(child_fixed_charge.reload).to have_attributes(
          properties: {"amount" => "300"},
          units: 10
        )
      end
    end
  end
end
