# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedCoupons::RecreditService do
  subject(:recredit_service) { described_class.new(credit:) }

  let(:customer) { create(:customer) }
  let(:organization) { customer.organization }
  let(:coupon) { create(:coupon, organization:) }
  let(:invoice) { create(:invoice, customer:, organization:, status: :finalized) }
  let(:applied_coupon) { create(:applied_coupon, coupon:, customer:, organization:) }
  let(:credit) { create(:credit, invoice:, applied_coupon:, amount_cents: 100) }

  describe "#call" do
    context "when applied_coupon is not found" do
      let(:credit) { create(:credit, invoice:, applied_coupon: nil) }

      it "returns a not_found failure" do
        result = recredit_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.resource).to eq("applied_coupon")
      end
    end

    context "when applied_coupon is terminated" do
      let(:applied_coupon) do
        create(:applied_coupon,
          coupon:,
          customer:,
          organization:,
          status: :terminated,
          terminated_at: Time.current)
      end

      context "when it should be reactivated" do
        it "reactivates the coupon" do
          expect {
            recredit_service.call
          }.to change { applied_coupon.reload.status }.from("terminated").to("active")
            .and change { applied_coupon.reload.terminated_at }.to(nil)
        end

        it "uses with_lock to prevent race conditions" do
          allow(applied_coupon).to receive(:with_lock).and_call_original
          recredit_service.call
          expect(applied_coupon).to have_received(:with_lock)
        end
      end

      context "when it is a forever coupon" do
        let(:applied_coupon) do
          create(:applied_coupon,
            coupon:,
            customer:,
            organization:,
            status: :terminated,
            terminated_at: Time.current,
            frequency: :forever)
        end

        it "does not reactivate the coupon" do
          expect {
            recredit_service.call
          }.not_to change { applied_coupon.reload.status }
        end
      end

      context "when the original coupon is terminated" do
        let(:coupon) { create(:coupon, organization:, status: :terminated) }

        it "does not reactivate the coupon" do
          expect {
            recredit_service.call
          }.not_to change { applied_coupon.reload.status }
        end
      end
    end

    context "when applied_coupon is recurring" do
      let(:applied_coupon) do
        create(:applied_coupon,
          coupon:,
          customer:,
          organization:,
          frequency: :recurring,
          frequency_duration: 3,
          frequency_duration_remaining: 2)
      end

      it "increments frequency_duration_remaining" do
        expect {
          recredit_service.call
        }.to change { applied_coupon.reload.frequency_duration_remaining }.from(2).to(3)
      end

      it "uses with_lock to prevent race conditions" do
        allow(applied_coupon).to receive(:with_lock).and_call_original
        recredit_service.call
        expect(applied_coupon).to have_received(:with_lock)
      end
    end
  end
end
