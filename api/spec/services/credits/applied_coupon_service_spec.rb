# frozen_string_literal: true

require "rails_helper"

RSpec.describe Credits::AppliedCouponService do
  subject(:credit_service) do
    described_class.new(invoice:, applied_coupon:)
  end

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }

  let(:invoice) do
    create(
      :invoice,
      organization:,
      customer:,
      currency: "EUR",
      sub_total_excluding_taxes_amount_cents: base_amount_cents
    )
  end
  let(:base_amount_cents) { 300 }

  let(:coupon) { create(:coupon, organization:) }
  let(:applied_coupon) { create(:applied_coupon, amount_cents: 12, coupon:, customer:) }

  let(:fee1) { create(:fee, amount_cents: base_amount_cents / 3 * 2, invoice:) }
  let(:fee2) { create(:fee, amount_cents: base_amount_cents / 3, invoice:) }

  before do
    fee1
    fee2
  end

  context "without lock" do
    describe "call" do
      it "fails with a service failure" do
        result = credit_service.call

        expect(result).not_to be_success
        expect(result.error.code).to eq("no_lock_acquired")
      end
    end
  end

  context "with lock acquired" do
    around do |spec|
      customer.with_advisory_lock("COUPONS-#{customer.id}", &spec)
    end

    describe "call" do
      it "creates a credit" do
        result = credit_service.call

        expect(result).to be_success
        expect(result.credit.amount_cents).to eq(12)
        expect(result.credit.amount_currency).to eq("EUR")
        expect(result.credit.invoice).to eq(invoice)
        expect(result.credit.applied_coupon).to eq(applied_coupon)
        expect(result.credit.before_taxes).to eq(true)

        expect(fee1.reload.precise_coupons_amount_cents).to eq(8)
        expect(fee2.reload.precise_coupons_amount_cents).to eq(4)
      end

      it "terminates the applied coupon" do
        result = credit_service.call

        expect(result).to be_success
        expect(applied_coupon.reload).to be_terminated
      end

      context "when base_amount_cents is equal to 0" do
        let(:base_amount_cents) { 0 }

        it "limits the credit amount to the invoice amount" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(0)
        end
      end

      context "when coupon amount is higher than invoice amount" do
        let(:base_amount_cents) { 6 }

        it "limits the credit amount to the invoice amount" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(6)

          expect(fee1.reload.precise_coupons_amount_cents).to eq(4)
          expect(fee2.reload.precise_coupons_amount_cents).to eq(2)
        end

        it "does not terminate the applied coupon" do
          result = credit_service.call

          expect(result).to be_success
          expect(applied_coupon.reload).not_to be_terminated
        end
      end

      context "when credit has already been applied" do
        before do
          create(
            :credit,
            invoice:,
            applied_coupon:,
            amount_cents: 12,
            amount_currency: "EUR"
          )
        end

        it "does not create another credit" do
          expect { credit_service.call }
            .not_to change(Credit, :count)
        end
      end

      context "when coupon is partially used" do
        before do
          create(
            :credit,
            applied_coupon:,
            amount_cents: 6
          )
        end

        it "applies the remaining amount" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(6)
          expect(result.credit.amount_currency).to eq("EUR")
          expect(result.credit.invoice).to eq(invoice)
          expect(result.credit.applied_coupon).to eq(applied_coupon)

          expect(fee1.reload.precise_coupons_amount_cents).to eq(4)
          expect(fee2.reload.precise_coupons_amount_cents).to eq(2)
        end

        it "terminates the applied coupon" do
          result = credit_service.call

          expect(result).to be_success
          expect(applied_coupon.reload).to be_terminated
        end
      end

      context "when coupon is percentage" do
        let(:coupon) { create(:coupon, coupon_type: "percentage", percentage_rate: 10.00) }

        let(:applied_coupon) do
          create(:applied_coupon, coupon:, percentage_rate: 20.00)
        end

        it "creates a credit" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(60)
          expect(result.credit.amount_currency).to eq("EUR")
          expect(result.credit.invoice).to eq(invoice)
          expect(result.credit.applied_coupon).to eq(applied_coupon)

          expect(fee1.reload.precise_coupons_amount_cents).to eq(40)
          expect(fee2.reload.precise_coupons_amount_cents).to eq(20)
        end

        it "terminates the applied coupon" do
          result = credit_service.call

          expect(result).to be_success
          expect(applied_coupon.reload).to be_terminated
        end
      end

      context "when coupon is recurring and fixed amount" do
        let(:coupon) { create(:coupon, frequency: "recurring", frequency_duration: 3) }

        let(:applied_coupon) do
          create(
            :applied_coupon,
            coupon:,
            frequency: "recurring",
            frequency_duration: 3,
            frequency_duration_remaining: 3,
            amount_cents: 12
          )
        end

        it "creates a credit" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(12)
          expect(result.credit.amount_currency).to eq("EUR")
          expect(result.credit.invoice).to eq(invoice)
          expect(result.credit.applied_coupon).to eq(applied_coupon)
          expect(result.credit.applied_coupon.frequency_duration).to eq(3)
          expect(result.credit.applied_coupon.frequency_duration_remaining).to eq(2)

          expect(fee1.reload.precise_coupons_amount_cents).to eq(8)
          expect(fee2.reload.precise_coupons_amount_cents).to eq(4)
        end

        it "does not terminate the applied coupon" do
          result = credit_service.call

          expect(result).to be_success
          expect(applied_coupon.reload).not_to be_terminated
        end

        context "when coupon amount is higher than invoice amount" do
          let(:base_amount_cents) { 6 }

          it "limits the credit amount to the invoice amount" do
            result = credit_service.call

            expect(result).to be_success
            expect(result.credit.amount_cents).to eq(6)

            expect(fee1.reload.precise_coupons_amount_cents).to eq(4)
            expect(fee2.reload.precise_coupons_amount_cents).to eq(2)
          end
        end
      end

      context "when coupon is forever and fixed amount" do
        let(:coupon) { create(:coupon, frequency: "forever", frequency_duration: 0) }

        let(:applied_coupon) do
          create(
            :applied_coupon,
            coupon:,
            frequency: "forever",
            frequency_duration: 0,
            frequency_duration_remaining: 0,
            amount_cents: 12
          )
        end

        it "creates a credit" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(12)
          expect(result.credit.amount_currency).to eq("EUR")
          expect(result.credit.invoice).to eq(invoice)
          expect(result.credit.applied_coupon).to eq(applied_coupon)
          expect(result.credit.applied_coupon.frequency_duration).to eq(0)
          expect(result.credit.applied_coupon.frequency_duration_remaining).to eq(0)

          expect(fee1.reload.precise_coupons_amount_cents).to eq(8)
          expect(fee2.reload.precise_coupons_amount_cents).to eq(4)
        end

        it "does not terminate the applied coupon" do
          result = credit_service.call

          expect(result).to be_success
          expect(applied_coupon.reload).not_to be_terminated
        end

        context "when coupon amount is higher than invoice amount" do
          let(:base_amount_cents) { 6 }

          it "limits the credit amount to the invoice amount" do
            result = credit_service.call

            expect(result).to be_success
            expect(result.credit.amount_cents).to eq(6)

            expect(fee1.reload.precise_coupons_amount_cents).to eq(4)
            expect(fee2.reload.precise_coupons_amount_cents).to eq(2)
          end
        end
      end

      context "when coupon is recurring and percentage" do
        let(:coupon) do
          create(:coupon, frequency: "recurring", frequency_duration: 3, coupon_type: "percentage", percentage_rate: 10)
        end

        let(:applied_coupon) do
          create(
            :applied_coupon,
            coupon:,
            frequency: "recurring",
            frequency_duration: 3,
            frequency_duration_remaining: 3,
            percentage_rate: 20.00
          )
        end

        it "creates a credit" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(60)
          expect(result.credit.amount_currency).to eq("EUR")
          expect(result.credit.invoice).to eq(invoice)
          expect(result.credit.applied_coupon).to eq(applied_coupon)
          expect(result.credit.applied_coupon.frequency_duration).to eq(3)
          expect(result.credit.applied_coupon.frequency_duration_remaining).to eq(2)

          expect(fee1.reload.precise_coupons_amount_cents).to eq(40)
          expect(fee2.reload.precise_coupons_amount_cents).to eq(20)
        end

        it "does not terminate the applied coupon" do
          result = credit_service.call

          expect(result).to be_success
          expect(applied_coupon.reload).not_to be_terminated
        end

        context "when frequency duration becomes zero" do
          let(:applied_coupon) do
            create(
              :applied_coupon,
              coupon:,
              frequency: "recurring",
              frequency_duration: 3,
              frequency_duration_remaining: 1,
              percentage_rate: 20.00
            )
          end

          it "creates a credit" do
            result = credit_service.call

            expect(result).to be_success
            expect(result.credit.amount_cents).to eq(60)
            expect(result.credit.amount_currency).to eq("EUR")
            expect(result.credit.invoice).to eq(invoice)
            expect(result.credit.applied_coupon).to eq(applied_coupon)
            expect(result.credit.applied_coupon.frequency_duration).to eq(3)
            expect(result.credit.applied_coupon.frequency_duration_remaining).to eq(0)

            expect(fee1.reload.precise_coupons_amount_cents).to eq(40)
            expect(fee2.reload.precise_coupons_amount_cents).to eq(20)
          end

          it "terminates the applied coupon" do
            result = credit_service.call

            expect(result).to be_success
            expect(applied_coupon.reload).to be_terminated
          end
        end
      end

      context "when currencies does not match" do
        let(:applied_coupon) do
          create(
            :applied_coupon,
            customer:,
            amount_cents: 10,
            amount_currency: "NOK"
          )
        end

        it "does not create a credit" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit).to be_nil
        end

        context "when coupon is percentage" do
          let(:coupon) { create(:coupon, organization:, coupon_type: :percentage, percentage_rate: 10) }
          let(:applied_coupon) do
            create(
              :applied_coupon,
              coupon:,
              customer:,
              percentage_rate: 10,
              amount_currency: "NOK"
            )
          end

          it "creates a credit regardless of currency" do
            result = credit_service.call

            expect(result).to be_success
            expect(result.credit).to be_present
            expect(result.credit.amount_currency).to eq("EUR")
          end
        end
      end

      context "when coupon have plan limitations" do
        let(:coupon) { create(:coupon, coupon_type: "fixed_amount", limited_plans: true) }
        let(:plan) { create(:plan, organization:) }
        let(:coupon_target) { create(:coupon_plan, coupon:, plan:) }

        let(:subscription) { create(:subscription, plan:, customer:) }
        let(:fee1) { create(:fee, amount_cents: base_amount_cents, invoice:, subscription:) }

        before { coupon_target }

        it "creates a credit" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(12)
          expect(result.credit.amount_currency).to eq("EUR")
          expect(result.credit.invoice).to eq(invoice)
          expect(result.credit.applied_coupon).to eq(applied_coupon)
          expect(result.credit.before_taxes).to eq(true)

          expect(fee1.reload.precise_coupons_amount_cents).to eq(12)
          expect(fee2.reload.precise_coupons_amount_cents).to eq(0)
        end

        context "when plan limitation does not applies" do
          let(:subscription) { create(:subscription, customer:) }

          it "does not create a credit" do
            result = credit_service.call

            expect(result).to be_success
            expect(result.credit).to be_nil
          end
        end
      end

      context "when coupon have billable metric limitations" do
        let(:coupon) { create(:coupon, coupon_type: "fixed_amount", limited_billable_metrics: true) }
        let(:plan) { create(:plan, organization:) }
        let(:billable_metric) { create(:billable_metric, organization:) }
        let(:charge) { create(:standard_charge, billable_metric:, plan:) }

        let(:coupon_target) { create(:coupon_billable_metric, coupon:, billable_metric:) }

        let(:subscription) { create(:subscription, plan:, customer:) }
        let(:fee1) { create(:charge_fee, charge:, amount_cents: base_amount_cents, invoice:, subscription:) }

        before { coupon_target }

        it "creates a credit" do
          result = credit_service.call

          expect(result).to be_success
          expect(result.credit.amount_cents).to eq(12)
          expect(result.credit.amount_currency).to eq("EUR")
          expect(result.credit.invoice).to eq(invoice)
          expect(result.credit.applied_coupon).to eq(applied_coupon)
          expect(result.credit.before_taxes).to eq(true)

          expect(fee1.reload.precise_coupons_amount_cents).to eq(12)
          expect(fee2.reload.precise_coupons_amount_cents).to eq(0)
        end

        context "with multiple fees and progressive billing credits already applied" do
          let(:fee3) { create(:fee, amount_cents: base_amount_cents / 3, invoice:, subscription:) }
          let(:fee1) do
            create(
              :charge_fee,
              charge:,
              amount_cents: base_amount_cents / 6,
              invoice:,
              subscription:,
              precise_coupons_amount_cents: 15 # weighted prog. billing credits
            )
          end
          let(:fee2) do
            create(
              :charge_fee,
              charge:,
              amount_cents: base_amount_cents / 2,
              invoice:,
              subscription:,
              precise_coupons_amount_cents: 45 # weighted prog.billing credits
            )
          end

          before { fee3 }

          it "creates a credit" do
            result = credit_service.call

            expect(result).to be_success
            expect(result.credit.amount_cents).to eq(12)
            expect(result.credit.amount_currency).to eq("EUR")
            expect(result.credit.invoice).to eq(invoice)
            expect(result.credit.applied_coupon).to eq(applied_coupon)
            expect(result.credit.before_taxes).to eq(true)

            expect(fee1.reload.precise_coupons_amount_cents).to eq(18)
            expect(fee2.reload.precise_coupons_amount_cents).to eq(54)
            expect(fee3.reload.precise_coupons_amount_cents).to eq(0)
          end
        end

        context "when plan limitation does not applies" do
          let(:charge) { create(:standard_charge, plan:) }

          it "does not create a credit" do
            result = credit_service.call

            expect(result).to be_success
            expect(result.credit).to be_nil
          end
        end
      end

      context "when frequency_duration_remaining is already 0" do
        let(:coupon) { create(:coupon, organization:, frequency: "recurring", frequency_duration: 3) }
        let(:applied_coupon) do
          create(
            :applied_coupon,
            coupon:,
            customer:,
            amount_cents: 12,
            frequency: "recurring",
            frequency_duration: 3,
            frequency_duration_remaining: 0
          )
        end

        it "does not decrement frequency_duration_remaining below 0" do
          result = credit_service.call

          expect(result).to be_success
          expect(applied_coupon.reload.frequency_duration_remaining).to eq(0)
        end
      end
    end
  end
end
