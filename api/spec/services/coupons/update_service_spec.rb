# frozen_string_literal: true

require "rails_helper"

RSpec.describe Coupons::UpdateService do
  subject(:update_service) { described_class.new(coupon:, params:) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }

  let(:coupon) { create(:coupon, organization:) }

  let(:params) do
    {
      name:,
      coupon_type: "fixed_amount",
      frequency: "once",
      amount_cents: 100,
      amount_currency: "EUR",
      expiration: "time_limit",
      reusable: false,
      expiration_at:,
      applies_to:
    }
  end

  let(:name) { "new name" }
  let(:expiration_at) { Time.current + 30.days }
  let(:applies_to) { nil }

  describe "#call" do
    it "updates the coupon" do
      result = update_service.call

      expect(result).to be_success

      expect(result.coupon.name).to eq("new name")
      expect(result.coupon.amount_cents).to eq(100)
      expect(result.coupon.amount_currency).to eq("EUR")
      expect(result.coupon.expiration).to eq("time_limit")
      expect(result.coupon.reusable).to eq(false)
      expect(result.coupon.expiration_at.to_s).to eq(expiration_at.to_s)
    end

    it "produces an activity log" do
      described_class.call(coupon:, params:)

      expect(Utils::ActivityLog).to have_produced("coupon.updated").after_commit.with(coupon)
    end

    context "with validation error" do
      let(:name) { nil }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:name]).to eq(["value_is_mandatory"])
      end
    end

    context "when frequency is recurring without frequency_duration" do
      let(:params) do
        {
          name:,
          coupon_type: "fixed_amount",
          frequency: "recurring",
          amount_cents: 100,
          amount_currency: "EUR",
          expiration: "no_expiration",
          reusable: false
        }
      end

      it "fails with a validation error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:frequency_duration]).to eq(["value_is_mandatory", "is not a number"])
      end
    end

    context "with new plan limitations" do
      let(:plan) { create(:plan, organization:) }
      let(:plan_second) { create(:plan, organization:) }
      let(:coupon_plan) { create(:coupon_plan, coupon:, plan:) }
      let(:applies_to) { {plan_ids: [plan.id, plan_second.id]} }

      before do
        CurrentContext.source = "graphql"

        plan_second
        coupon_plan
      end

      it "creates new coupon target" do
        expect { update_service.call }.to change(CouponTarget, :count).by(1)
      end

      context "with API context" do
        before { CurrentContext.source = "api" }

        let(:applies_to) { {plan_codes: [plan.code, plan_second.code]} }

        it "creates new coupon target using plan code" do
          expect { update_service.call }.to change(CouponTarget, :count).by(1)
        end
      end
    end

    context "with coupon plans to delete" do
      let(:plan) { create(:plan, organization:) }
      let(:coupon_plan) { create(:coupon_plan, coupon:, plan:) }
      let(:applies_to) { {plan_ids: []} }

      before do
        CurrentContext.source = "graphql"

        coupon_plan
      end

      it "deletes a coupon plan" do
        expect { update_service.call }.to change(CouponTarget, :count).by(-1)
      end
    end

    context "with new billable metric limitations" do
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:billable_metric_second) { create(:billable_metric, organization:) }
      let(:coupon_billable_metric) { create(:coupon_billable_metric, coupon:, billable_metric:) }
      let(:applies_to) { {billable_metric_ids: [billable_metric.id, billable_metric_second.id]} }

      before do
        CurrentContext.source = "graphql"

        billable_metric_second
        coupon_billable_metric
      end

      it "creates new coupon target" do
        expect { update_service.call }.to change(CouponTarget, :count).by(1)
      end

      context "with API context" do
        before { CurrentContext.source = "api" }

        let(:applies_to) { {billable_metric_codes: [billable_metric.code, billable_metric_second.code]} }

        it "creates new coupon target using billable metric code" do
          expect { update_service.call }.to change(CouponTarget, :count).by(1)
        end
      end

      context "with multiple limitation types" do
        let(:plan) { create(:plan, organization:) }
        let(:applies_to) do
          {
            billable_metric_ids: [billable_metric.id, billable_metric_second.id],
            plan_ids: [plan.id]
          }
        end

        it "returns an error" do
          result = update_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("only_one_limitation_type_per_coupon_allowed")
        end
      end

      context "with invalid billable metric" do
        let(:applies_to) do
          {
            billable_metric_ids: [billable_metric.id, billable_metric_second.id, "invalid"]
          }
        end

        it "returns an error" do
          result = update_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("billable_metrics_not_found")
        end
      end
    end

    context "with coupon billable metrics to delete" do
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:coupon_billable_metric) { create(:coupon_billable_metric, coupon:, billable_metric:) }
      let(:applies_to) { {plan_ids: []} }

      before do
        CurrentContext.source = "graphql"

        coupon_billable_metric
      end

      it "deletes a coupon billable metric" do
        expect { update_service.call }.to change(CouponTarget, :count).by(-1)
      end
    end

    context "when coupon is not found" do
      let(:coupon) { nil }

      it "returns an error" do
        result = update_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::NotFoundFailure)
        expect(result.error.error_code).to eq("coupon_not_found")
      end
    end
  end
end
