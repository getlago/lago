# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::DestroyService do
  subject(:destroy_service) { described_class.new(fixed_charge:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:plan) { create(:plan, organization:) }
  let(:add_on) { create(:add_on, organization:) }
  let(:fixed_charge) { create(:fixed_charge, plan:, add_on:) }

  describe "#call" do
    it "soft deletes the fixed charge" do
      freeze_time do
        expect { destroy_service.call }.to change(FixedCharge, :count).by(-1)
          .and change { fixed_charge.reload.deleted_at }.from(nil).to(Time.current)
      end
    end

    it "returns the fixed charge in the result" do
      result = destroy_service.call

      expect(result).to be_success
      expect(result.fixed_charge).to eq(fixed_charge)
    end

    context "when fixed charge is not found" do
      let(:fixed_charge) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("fixed_charge_not_found")
      end
    end

    context "when fixed charge has associated records" do
      let(:tax) { create(:tax, organization:) }
      let(:applied_tax) { create(:fixed_charge_applied_tax, fixed_charge:, tax:) }
      let(:child_fixed_charge) { create(:fixed_charge, plan:, add_on:, parent: fixed_charge) }
      let(:fee) { create(:fee, fixed_charge:, organization:) }

      before do
        applied_tax
        child_fixed_charge
        fee
      end

      it "soft deletes the fixed charge and keeps associated records" do
        freeze_time do
          expect { destroy_service.call }.to change(FixedCharge, :count).by(-1)
            .and change { fixed_charge.reload.deleted_at }.from(nil).to(Time.current)
        end
      end

      it "does not delete associated applied taxes" do
        expect { destroy_service.call }.not_to change(FixedCharge::AppliedTax, :count)
      end

      it "does not delete child fixed charges" do
        expect { destroy_service.call }.not_to change { child_fixed_charge.reload.deleted_at }
      end

      it "does not delete associated fees" do
        expect { destroy_service.call }.not_to change { fee.reload.deleted_at }
      end
    end

    context "when fixed charge is already deleted" do
      let(:fixed_charge) { create(:fixed_charge, plan:, add_on:, deleted_at: 1.day.ago) }

      it "returns error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ServiceFailure)
        expect(result.error.code).to eq("fixed_charge_already_deleted")
      end
    end

    context "with cascade_updates" do
      subject(:destroy_service) { described_class.new(fixed_charge:, cascade_updates: true) }

      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_fixed_charge) { create(:fixed_charge, plan: child_plan, add_on:, parent: fixed_charge) }

      before do
        child_fixed_charge
        allow(FixedCharges::DestroyChildrenJob).to receive(:perform_later)
      end

      it "enqueues FixedCharges::DestroyChildrenJob" do
        destroy_service.call

        expect(FixedCharges::DestroyChildrenJob).to have_received(:perform_later).with(fixed_charge.id)
      end

      context "when fixed_charge has no children" do
        before { child_fixed_charge.update!(parent_id: nil) }

        it "does not enqueue FixedCharges::DestroyChildrenJob" do
          destroy_service.call

          expect(FixedCharges::DestroyChildrenJob).not_to have_received(:perform_later)
        end
      end
    end

    context "without cascade_updates when fixed_charge has children" do
      let(:child_plan) { create(:plan, organization:, parent: plan) }
      let(:child_fixed_charge) { create(:fixed_charge, plan: child_plan, add_on:, parent: fixed_charge) }

      before do
        child_fixed_charge
        allow(FixedCharges::DestroyChildrenJob).to receive(:perform_later)
      end

      it "does not enqueue FixedCharges::DestroyChildrenJob" do
        destroy_service.call

        expect(FixedCharges::DestroyChildrenJob).not_to have_received(:perform_later)
      end
    end
  end
end
