# frozen_string_literal: true

require "rails_helper"

RSpec.describe Coupons::TerminateService do
  subject(:terminate_service) { described_class.new(coupon) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:coupon) { create(:coupon, organization:) }

  describe "terminate" do
    it "terminates the coupon" do
      result = terminate_service.call

      expect(result).to be_success
      expect(result.coupon).to be_terminated
    end

    context "when coupon is already terminated" do
      before { coupon.mark_as_terminated! }

      it "does not impact the coupon" do
        terminated_at = coupon.terminated_at
        result = terminate_service.call

        expect(result).to be_success
        expect(result.coupon).to be_terminated
        expect(result.coupon.terminated_at).to eq(terminated_at)
      end
    end
  end

  describe "terminate_all_expired" do
    let(:to_expire_coupons) do
      create_list(
        :coupon,
        3,
        organization:,
        status: "active",
        expiration: "time_limit",
        expiration_at: Time.current - 30.days,
        created_at: Time.zone.now - 40.days
      )
    end

    let(:to_keep_active_coupons) do
      create_list(
        :coupon,
        3,
        organization:,
        status: "active",
        expiration: "time_limit",
        expiration_at: Time.current + 15.days,
        created_at: Time.zone.now
      )
    end

    before do
      to_expire_coupons
      to_keep_active_coupons

      described_class.terminate_all_expired
    end

    it "terminates the expired coupons" do
      expect(Coupon.terminated.count).to eq(3)
    end
  end
end
