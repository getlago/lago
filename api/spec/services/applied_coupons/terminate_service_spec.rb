# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedCoupons::TerminateService do
  subject(:terminate_service) { described_class.new(applied_coupon:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:coupon) { create(:coupon, status: "active", organization:) }
  let(:applied_coupon) { create(:applied_coupon, coupon:) }

  describe "#call" do
    it "terminates the applied coupon" do
      result = terminate_service.call

      expect(result).to be_success
      expect(result.applied_coupon).to be_terminated
    end

    it "produces an activity log" do
      described_class.call(applied_coupon:)

      expect(Utils::ActivityLog).to have_produced("applied_coupon.deleted").with(applied_coupon)
    end

    context "when applied coupon is already terminated" do
      before { applied_coupon.mark_as_terminated! }

      it "does not impact the applied coupon" do
        terminated_at = applied_coupon.reload.terminated_at
        result = terminate_service.call

        expect(result).to be_success
        expect(result.applied_coupon).to be_terminated
        expect(result.applied_coupon.terminated_at).to eq(terminated_at)
      end
    end
  end
end
