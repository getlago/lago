# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppliedCoupons::CreateService do
  subject(:create_service) do
    described_class.new(customer:, coupon:, params:)
  end

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:customer) { create(:customer, organization:) }
  let(:coupon) { create(:coupon, status: "active", organization:) }

  let(:amount_cents) { nil }
  let(:amount_currency) { nil }
  let(:percentage_rate) { nil }

  let(:params) do
    {
      amount_cents:,
      amount_currency:,
      percentage_rate:
    }
  end

  let(:create_subscription) { customer.present? }

  before do
    create(:subscription, customer:) if create_subscription
  end

  describe "create" do
    let(:create_result) { create_service.call }

    it "applied the coupon to the customer" do
      expect { create_result }.to change(AppliedCoupon, :count).by(1)

      expect(create_result.applied_coupon.customer).to eq(customer)
      expect(create_result.applied_coupon.coupon).to eq(coupon)
      expect(create_result.applied_coupon.amount_cents).to eq(coupon.amount_cents)
      expect(create_result.applied_coupon.amount_currency).to eq(coupon.amount_currency)
    end

    it "produces an activity log" do
      applied_coupon = described_class.call(customer:, coupon:, params:).applied_coupon

      expect(Utils::ActivityLog).to have_produced("applied_coupon.created").after_commit.with(applied_coupon)
    end

    context "when coupon type is percentage" do
      let(:coupon) do
        create(
          :coupon,
          status: "active",
          organization:,
          coupon_type: "percentage",
          percentage_rate: 10.00
        )
      end

      let(:percentage_rate) { 20.00 }

      before { customer.update!(currency: nil) }

      it "applies the coupon to the customer" do
        expect { create_result }.to change(AppliedCoupon, :count).by(1)
      end

      it "sets correct percentage rate" do
        expect(create_result.applied_coupon.percentage_rate).to eq(20.00)
      end

      it "does not try to update customer currency" do
        expect(create_result.applied_coupon.customer.currency).to eq nil
      end
    end

    context "when an other coupon is already applied to the customer" do
      let(:other_coupon) { create(:coupon, status: "active", organization:) }

      before { create(:applied_coupon, customer:, coupon:) }

      it "applied the coupon to the customer" do
        expect { create_result }.to change(AppliedCoupon, :count).by(1)

        expect(create_result.applied_coupon.customer).to eq(customer)
        expect(create_result.applied_coupon.coupon).to eq(coupon)
        expect(create_result.applied_coupon.organization).to eq(organization)
        expect(create_result.applied_coupon.amount_cents).to eq(coupon.amount_cents)
        expect(create_result.applied_coupon.amount_currency).to eq(coupon.amount_currency)
      end
    end

    context "with overridden amount" do
      let(:amount_cents) { 123 }
      let(:amount_currency) { "EUR" }

      it { expect(create_result.applied_coupon.amount_cents).to eq(123) }
      it { expect(create_result.applied_coupon.amount_currency).to eq("EUR") }

      context "when currency does not match" do
        let(:amount_currency) { "NOK" }

        before { customer.update!(currency: "EUR") }

        it "fails" do
          expect(create_result).not_to be_success
          expect(create_result.error).to be_a(BaseService::ValidationFailure)
          expect(create_result.error.messages.keys).to include(:currency)
          expect(create_result.error.messages[:currency]).to include("currencies_does_not_match")
        end
      end
    end

    context "when customer is not found" do
      let(:customer) { nil }

      it "returns a not found error" do
        expect(create_result).not_to be_success
        expect(create_result.error).to be_a(BaseService::NotFoundFailure)
        expect(create_result.error.message).to eq("customer_not_found")
      end
    end

    context "when coupon is not found" do
      let(:coupon) { nil }

      it "returns a not found error" do
        expect(create_result).not_to be_success
        expect(create_result.error).to be_a(BaseService::NotFoundFailure)
        expect(create_result.error.message).to eq("coupon_not_found")
      end
    end

    context "when coupon is already applied to the customer and is not reusable" do
      let(:coupon) { create(:coupon, status: "active", organization:, reusable: false) }

      before { create(:applied_coupon, customer:, coupon:) }

      it "fails" do
        expect(create_result).not_to be_success
        expect(create_result.error).to be_a(BaseService::ValidationFailure)
        expect(create_result.error.messages.keys).to include(:coupon)
        expect(create_result.error.messages[:coupon]).to include("coupon_is_not_reusable")
      end
    end

    context "when coupon is already applied with the plan limitation" do
      let(:plan) { create(:plan, organization:) }
      let(:coupon_old) { create(:coupon, status: "active", organization:, limited_plans: true) }
      let(:coupon) { create(:coupon, status: "active", organization:, limited_plans: true) }
      let(:coupon_plan_old) { create(:coupon_plan, coupon: coupon_old, plan:) }
      let(:coupon_plan) { create(:coupon_plan, coupon:, plan:) }

      before do
        coupon_plan_old
        create(:applied_coupon, customer:, coupon: coupon_old)
      end

      context "when newly applied coupon has the same plan limitation" do
        before { coupon_plan }

        it "fails" do
          expect(create_result).not_to be_success
          expect(create_result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(create_result.error.code).to eq("plan_overlapping")
        end
      end

      context "when newly applied coupon has the BM limitation that overlaps with already applied plan limitation" do
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:charge) { create(:standard_charge, plan:, billable_metric:) }
        let(:coupon) { create(:coupon, status: "active", organization:, limited_billable_metrics: true) }
        let(:coupon_billable_metric) { create(:coupon_billable_metric, coupon:, billable_metric:) }

        before do
          charge
          coupon_billable_metric
        end

        it "fails" do
          expect(create_result).not_to be_success
          expect(create_result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(create_result.error.code).to eq("plan_overlapping")
        end
      end

      context "when newly applied coupon has the plan limitation that overlaps with already applied BM limitation" do
        let(:coupon_old) { create(:coupon, status: "active", organization:, limited_billable_metrics: true) }
        let(:coupon_bm_old) { create(:coupon_billable_metric, coupon: coupon_old, billable_metric:) }
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:charge) { create(:standard_charge, plan:, billable_metric:) }
        let(:coupon) { create(:coupon, status: "active", organization:, limited_plans: true) }
        let(:coupon_plan) { create(:coupon_plan, coupon:, plan:) }

        before do
          charge
          coupon_bm_old
          coupon_plan
        end

        it "fails" do
          expect(create_result).not_to be_success
          expect(create_result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(create_result.error.code).to eq("plan_overlapping")
        end
      end
    end

    context "when coupon is inactive" do
      before { coupon.terminated! }

      it "returns a not found error" do
        expect(create_result).not_to be_success
        expect(create_result.error).to be_a(BaseService::NotFoundFailure)
        expect(create_result.error.message).to eq("coupon_not_found")
      end
    end

    context "when currency of coupon does not match customer currency" do
      let(:coupon) { create(:coupon, status: "active", organization:, amount_currency: "NOK") }

      before { customer.update!(currency: "EUR") }

      it "fails" do
        expect(create_result).not_to be_success
        expect(create_result.error).to be_a(BaseService::ValidationFailure)
        expect(create_result.error.messages.keys).to include(:currency)
        expect(create_result.error.messages[:currency]).to include("currencies_does_not_match")
      end
    end

    context "when customer does not have a currency" do
      let(:create_subscription) { false }
      let(:amount_currency) { "NOK" }

      before { customer.update!(currency: nil) }

      it "assigns the coupon currency to the customer" do
        create_result

        expect(customer.reload.currency).to eq(amount_currency)
      end
    end

    context "when frequency is overridden to recurring without frequency_duration" do
      let(:coupon) do
        create(:coupon, status: "active", organization:, frequency: "once", frequency_duration: nil)
      end

      let(:params) do
        {
          amount_cents:,
          amount_currency:,
          percentage_rate:,
          frequency: "recurring"
        }
      end

      it "fails with a validation error" do
        expect { create_result }.not_to change(AppliedCoupon, :count)

        expect(create_result).not_to be_success
        expect(create_result.error).to be_a(BaseService::ValidationFailure)
        expect(create_result.error.messages[:frequency_duration]).to eq(["value_is_mandatory", "is not a number"])
        expect(create_result.error.messages[:frequency_duration_remaining]).to eq(["value_is_mandatory", "is not a number"])
      end
    end
  end
end
