# frozen_string_literal: true

require "rails_helper"

describe AppliedCoupons::RecreditJob do
  subject(:perform_job) { described_class.perform_now(credit) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:invoice) { create(:invoice, organization:, customer:) }
  let(:applied_coupon) { create(:applied_coupon, organization:, customer:) }
  let(:credit) { create(:credit, organization:, invoice:, applied_coupon:) }

  before { allow(AppliedCoupons::RecreditService).to receive(:call!) }

  context "when the applied coupon is present" do
    it "delegates to AppliedCoupons::RecreditService" do
      perform_job

      expect(AppliedCoupons::RecreditService).to have_received(:call!).with(credit:)
    end
  end

  context "when the applied coupon is nil" do
    let(:credit) { create(:credit, organization:, invoice:, applied_coupon: nil) }

    it "does not call AppliedCoupons::RecreditService" do
      perform_job

      expect(AppliedCoupons::RecreditService).not_to have_received(:call!)
    end
  end
end
