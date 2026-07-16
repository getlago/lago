# frozen_string_literal: true

require "rails_helper"

RSpec.describe Coupons::CreateService do
  subject(:create_service) { described_class.new(create_args) }

  let(:membership) { create(:membership) }
  let(:organization) { membership.organization }
  let(:coupon_code) { "free-beer" }

  describe "create" do
    let(:expiration_at) { (Time.current + 3.days).end_of_day }
    let(:create_args) do
      {
        name: "Super Coupon",
        code: coupon_code,
        description: "This is a description",
        organization_id: organization.id,
        coupon_type: "fixed_amount",
        frequency: "once",
        amount_cents: 100,
        amount_currency: "EUR",
        expiration: "time_limit",
        reusable: false,
        expiration_at:
      }
    end

    it "creates a coupon" do
      expect { create_service.call }
        .to change(Coupon, :count).by(1)
    end

    it "produces an activity log" do
      coupon = described_class.call(create_args).coupon

      expect(Utils::ActivityLog).to have_produced("coupon.created").after_commit.with(coupon)
    end

    context "with code already used by a deleted coupon" do
      it "creates an coupon with the same code" do
        create(:coupon, :deleted, organization:, code: coupon_code)

        expect { create_service.call }.to change(Coupon, :count).by(1)

        coupons = organization.coupons.with_discarded
        expect(coupons.count).to eq(2)
        expect(coupons.pluck(:code).uniq).to eq([coupon_code])
      end
    end

    context "when coupon type is percentage" do
      let(:create_args) do
        {
          name: "Super Coupon",
          code: "free-beer",
          organization_id: organization.id,
          coupon_type: "percentage",
          frequency: "once",
          percentage_rate: 20.00,
          expiration: "time_limit",
          expiration_at: (Time.current + 3.days).iso8601
        }
      end

      it "creates a coupon" do
        expect { create_service.call }
          .to change(Coupon, :count).by(1)
      end
    end

    context "with non-ISO8601 expiration_at" do
      let(:expiration_at) { "2064-12-13 12:00:00" }

      it "creates a coupon" do
        expect { create_service.call }
          .to change(Coupon, :count).by(1)
      end
    end

    context "with validation error" do
      before do
        create(:coupon, organization:, code: coupon_code)
      end

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:code]).to eq(["value_already_exist"])
      end
    end

    context "with expiration_at in the past" do
      let(:expiration_at) { (Time.current - 3.days).end_of_day }

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])
      end
    end

    context "with invalid expiration_at" do
      let(:expiration_at) { "invalid-date" }

      it "returns an error" do
        result = create_service.call

        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:expiration_at]).to eq(["invalid_date"])
      end
    end

    context "when frequency is recurring without frequency_duration" do
      let(:create_args) do
        {
          name: "Super Coupon",
          code: coupon_code,
          organization_id: organization.id,
          coupon_type: "fixed_amount",
          frequency: "recurring",
          amount_cents: 100,
          amount_currency: "EUR",
          expiration: "no_expiration",
          reusable: false
        }
      end

      it "fails with a validation error" do
        expect { create_service.call }.not_to change(Coupon, :count)

        result = create_service.call
        expect(result).not_to be_success
        expect(result.error).to be_a(BaseService::ValidationFailure)
        expect(result.error.messages[:frequency_duration]).to eq(["value_is_mandatory", "is not a number"])
      end
    end

    context "with plan limitations in graphql context" do
      let(:plan) { create(:plan, organization:) }
      let(:create_args) do
        {
          name: "Super Coupon",
          code: "free-beer",
          organization_id: organization.id,
          coupon_type: "fixed_amount",
          frequency: "once",
          amount_cents: 100,
          amount_currency: "EUR",
          expiration: "time_limit",
          reusable: false,
          expiration_at:,
          applies_to: {
            plan_ids: [plan.id]
          }
        }
      end

      before { CurrentContext.source = "graphql" }

      it "creates a coupon" do
        expect { create_service.call }
          .to change(Coupon, :count).by(1)
      end

      it "creates a coupon target" do
        expect { create_service.call }
          .to change(CouponTarget, :count).by(1)
      end
    end

    context "with plan limitations in api context" do
      let(:plan) { create(:plan, organization:) }
      let(:create_args) do
        {
          name: "Super Coupon",
          code: "free-beer",
          organization_id: organization.id,
          coupon_type: "fixed_amount",
          frequency: "once",
          amount_cents: 100,
          amount_currency: "EUR",
          expiration: "time_limit",
          reusable: false,
          expiration_at:,
          applies_to: {
            plan_codes: [plan.code]
          }
        }
      end

      before { CurrentContext.source = "api" }

      it "creates a coupon" do
        expect { create_service.call }
          .to change(Coupon, :count).by(1)
      end

      it "creates a coupon target" do
        expect { create_service.call }
          .to change(CouponTarget, :count).by(1)
      end

      context "when a parent plan has childs" do
        let(:child_plan) { create(:plan, organization:, parent: plan, code: plan.code) }

        before { child_plan }

        it "creates a coupon" do
          expect { create_service.call }
            .to change(Coupon, :count).by(1)
        end

        it "creates a coupon target" do
          expect { create_service.call }
            .to change(CouponTarget, :count).by(2)
        end
      end
    end

    context "with billable metric limitations in graphql context" do
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:create_args) do
        {
          name: "Super Coupon",
          code: "free-beer",
          organization_id: organization.id,
          coupon_type: "fixed_amount",
          frequency: "once",
          amount_cents: 100,
          amount_currency: "EUR",
          expiration: "time_limit",
          reusable: false,
          expiration_at:,
          applies_to: {
            billable_metric_ids: [billable_metric.id]
          }
        }
      end

      before { CurrentContext.source = "graphql" }

      it "creates a coupon" do
        expect { create_service.call }
          .to change(Coupon, :count).by(1)
      end

      it "creates a coupon target" do
        expect { create_service.call }
          .to change(CouponTarget, :count).by(1)
      end

      context "with multiple limitation types" do
        let(:plan) { create(:plan, organization:) }
        let(:create_args) do
          {
            name: "Super Coupon",
            code: "free-beer",
            organization_id: organization.id,
            coupon_type: "fixed_amount",
            frequency: "once",
            amount_cents: 100,
            amount_currency: "EUR",
            expiration: "time_limit",
            reusable: false,
            expiration_at:,
            applies_to: {
              billable_metric_ids: [billable_metric.id],
              plan_ids: [plan.id]
            }
          }
        end

        it "returns an error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::MethodNotAllowedFailure)
          expect(result.error.code).to eq("only_one_limitation_type_per_coupon_allowed")
        end
      end

      context "with invalid billable metric" do
        let(:create_args) do
          {
            name: "Super Coupon",
            code: "free-beer",
            organization_id: organization.id,
            coupon_type: "fixed_amount",
            frequency: "once",
            amount_cents: 100,
            amount_currency: "EUR",
            expiration: "time_limit",
            reusable: false,
            expiration_at:,
            applies_to: {
              billable_metric_ids: [billable_metric.id, "invalid"]
            }
          }
        end

        it "returns an error" do
          result = create_service.call

          expect(result).not_to be_success
          expect(result.error).to be_a(BaseService::NotFoundFailure)
          expect(result.error.message).to eq("billable_metrics_not_found")
        end
      end
    end

    context "with billable metric limitations in api context" do
      let(:billable_metric) { create(:billable_metric, organization:) }
      let(:create_args) do
        {
          name: "Super Coupon",
          code: "free-beer",
          organization_id: organization.id,
          coupon_type: "fixed_amount",
          frequency: "once",
          amount_cents: 100,
          amount_currency: "EUR",
          expiration: "time_limit",
          reusable: false,
          expiration_at:,
          applies_to: {
            billable_metric_codes: [billable_metric.code]
          }
        }
      end

      before { CurrentContext.source = "api" }

      it "creates a coupon" do
        expect { create_service.call }
          .to change(Coupon, :count).by(1)
      end

      it "creates a coupon target" do
        expect { create_service.call }
          .to change(CouponTarget, :count).by(1)
      end
    end
  end
end
