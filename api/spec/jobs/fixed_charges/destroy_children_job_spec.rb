# frozen_string_literal: true

require "rails_helper"

RSpec.describe FixedCharges::DestroyChildrenJob do
  let(:fixed_charge) { create(:fixed_charge, :deleted) }

  before do
    allow(FixedCharges::DestroyChildrenService).to receive(:call!)
      .and_call_original
  end

  it "calls the service with the fixed charge" do
    described_class.perform_now(fixed_charge.id)

    expect(FixedCharges::DestroyChildrenService).to have_received(:call!).with(fixed_charge).once
  end

  context "when fixed charge is not found" do
    it "calls the service with nil" do
      described_class.perform_now("non-existent-id")

      expect(FixedCharges::DestroyChildrenService).to have_received(:call!).with(nil).once
    end
  end

  context "when fixed charge exists but is not deleted" do
    let(:fixed_charge) { create(:fixed_charge) }

    it "still calls the service" do
      described_class.perform_now(fixed_charge.id)

      expect(FixedCharges::DestroyChildrenService).to have_received(:call!).with(fixed_charge).once
    end
  end
end
