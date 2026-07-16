# frozen_string_literal: true

require "rails_helper"

describe "Billing Minimum Commitments In Arrears Scenario" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:timezone) { "UTC" }
  let(:customer) { create(:customer, organization:, timezone:) }

  let(:plan) do
    create(
      :plan,
      name: "In Arrears",
      code: "in_arrears",
      organization:,
      amount_cents: 10_000,
      interval: plan_interval,
      pay_in_advance: false
    )
  end

  let(:invoice) { subscription.reload.invoices.order(sequential_id: :desc).first }
  let(:subscription) { customer.subscriptions.first.reload }

  let(:billable_metric_metered) do
    create(
      :billable_metric,
      organization:,
      name: "Metered in arrears",
      code: "metered",
      aggregation_type: "sum_agg",
      field_name: "total",
      recurring: false
    )
  end

  let(:billable_metric_metered_advance) do
    create(
      :billable_metric,
      organization:,
      name: "Metered in advance",
      code: "metered_advance",
      aggregation_type: "sum_agg",
      field_name: "total",
      recurring: false
    )
  end

  let(:billable_metric_recurring_advance) do
    create(
      :billable_metric,
      organization:,
      name: "In advance recurring",
      code: "advance_recurring",
      aggregation_type: "sum_agg",
      field_name: "total",
      recurring: true
    )
  end

  let(:billing_time) { "calendar" }
  let(:plan_interval) { "quarterly" }
  let(:subscription_time) { DateTime.new(2024, 3, 12, 10) }
  let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

  before do
    minimum_commitment

    create(
      :standard_charge,
      billable_metric: billable_metric_metered,
      invoiceable: true,
      plan:,
      properties: {amount: "1"}
    )

    create(
      :standard_charge,
      :pay_in_advance,
      billable_metric: billable_metric_metered_advance,
      invoiceable: true,
      plan:,
      properties: {amount: "1"}
    )

    create(
      :standard_charge,
      :pay_in_advance,
      billable_metric: billable_metric_recurring_advance,
      invoiceable: true,
      plan:,
      properties: {amount: "1"}
    )

    # Create the subscription
    travel_to(subscription_time) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code,
          billing_time:
        }
      )

      create_event(
        {
          code: billable_metric_recurring_advance.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {total: "10"}
        }
      )

      create_event(
        {
          code: billable_metric_metered.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {total: "10"}
        }
      )

      create_event(
        {
          code: billable_metric_metered_advance.code,
          transaction_id: SecureRandom.uuid,
          external_subscription_id: customer.external_id,
          properties: {total: "10"}
        }
      )
    end

    travel_to((subscription_time + 3.months).beginning_of_quarter) do
      perform_billing
    end
  end

  context "when coupons are not applied" do
    context "when subscription is billed for the first period" do
      it "creates an invoice with minimum commitment fee" do
        travel_to((subscription_time + 3.months).beginning_of_quarter) do
          expect(invoice.fees.commitment.first.amount_cents).to eq(214_582)
        end
      end
    end

    context "when subscription is billed for the second period" do
      before do
        travel_to((subscription_time + 6.months).beginning_of_quarter) do
          perform_billing
        end
      end

      it "creates an invoice with minimum commitment fee" do
        travel_to((subscription_time + 6.months).beginning_of_quarter) do
          expect(invoice.fees.commitment.first.amount_cents).to eq(989_000)
        end
      end
    end
  end

  context "when coupon is applied" do
    let(:coupon) do
      create(
        :coupon,
        organization:,
        amount_cents: 1_000_000,
        frequency: :forever
      )
    end

    let(:coupon_target) { create(:coupon_plan, coupon:, plan:) }

    before do
      apply_coupon(
        {external_customer_id: customer.external_id,
         coupon_code: coupon_target.coupon.code,
         amount_cents: 1_000_000}
      )

      travel_to((subscription_time + 3.months).beginning_of_quarter) do
        perform_billing
      end
    end

    context "when subscription is billed for the first period" do
      it "creates an invoice with minimum commitment fee" do
        travel_to(subscription_time + 3.months) do
          expect(invoice.fees.commitment.first.amount_cents).to eq(214_582)
        end
      end
    end

    context "when subscription is billed for the second period" do
      before do
        travel_to((subscription_time + 6.months).beginning_of_quarter) do
          perform_billing
        end
      end

      it "creates an invoice with minimum commitment fee" do
        travel_to((subscription_time + 6.months).beginning_of_quarter) do
          expect(invoice.fees.commitment.first.amount_cents).to eq(989_000)
        end
      end
    end
  end
end
