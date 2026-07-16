# frozen_string_literal: true

require "rails_helper"

RSpec.describe AddOns::DestroyService do
  subject(:destroy_service) { described_class.new(add_on:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:add_on) { create(:add_on, organization:) }

  describe "#call" do
    before { add_on }

    it "soft deletes the add-on" do
      expect { destroy_service.call }.to change(AddOn, :count).by(-1)
        .and change { add_on.reload.deleted_at }.from(nil)
    end

    context "when there are fixed charges associated with the add-on" do
      let(:fixed_charges) { create_list(:fixed_charge, 2, add_on:) }

      before { fixed_charges }

      it "soft deletes the add-on and the fixed charges" do
        expect { destroy_service.call }.to change(AddOn, :count).by(-1)
          .and change { add_on.reload.deleted_at }.from(nil)
          .and change(FixedCharge, :count).by(-2)
          .and change { fixed_charges.map(&:reload).map(&:deleted_at) }.from([nil, nil]).to(all(be_present))
      end

      context "when failed to discard fixed charges" do
        before do
          allow(add_on.fixed_charges).to receive(:update_all).and_raise(ActiveRecord::RecordInvalid.new(fixed_charges.first))
        end

        it "does not soft delete the add-on" do
          result = destroy_service.call

          expect(result).not_to be_success
          expect(add_on.reload.deleted_at).to be_nil
        end
      end
    end

    context "when add-on is not found" do
      let(:add_on) { nil }

      it "returns an error" do
        result = destroy_service.call

        expect(result).not_to be_success
        expect(result.error.error_code).to eq("add_on_not_found")
      end
    end
  end
end
