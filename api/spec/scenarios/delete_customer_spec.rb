# frozen_string_literal: true

require "rails_helper"

describe "Delete Customer Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }
  let(:plan) { create(:plan, pay_in_advance: true, organization:, amount_cents: 1000) }
  let(:metric) { create(:billable_metric, organization:) }

  it "deletes the customer and terminate relations" do
    ### 15 Dec: Create subscription + charge.
    dec15 = DateTime.new(2022, 12, 15)

    travel_to(dec15) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code
        }
      )

      create(:standard_charge, plan:, billable_metric: metric, properties: {amount: "3"})
    end

    subscription = customer.subscriptions.find_by(external_id: customer.external_id)
    dec_invoice = subscription.invoices.first
    expect(dec_invoice).to be_draft

    ### 1 Jan: Billing
    jan1 = DateTime.new(2023, 1, 1)

    travel_to(jan1) do
      perform_billing
      expect(subscription.invoices.count).to eq(2)
    end

    jan_invoice = subscription.invoices.order(created_at: :desc).first
    expect(jan_invoice).to be_draft

    ### 10 Jan: Delete Plan
    jan20 = DateTime.new(2023, 1, 20)

    travel_to(jan20) do
      # Downgrade subscription
      downgrade_plan = create(:plan, organization:, amount_cents: 500)
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: downgrade_plan.code,
          subscription_at: "2023-02-01T00:00:00Z"
        }
      )
      pending_subscription = customer.subscriptions.pending.first

      # Create coupon and apply it to customer
      create_coupon(
        {
          name: "coupon1",
          code: "coupon1_code",
          coupon_type: "fixed_amount",
          frequency: "once",
          amount_cents: 123,
          amount_currency: "EUR",
          expiration: "time_limit",
          expiration_at: Time.current + 15.days,
          reusable: false
        }
      )
      apply_coupon(
        {
          external_customer_id: customer.external_id,
          coupon_code: "coupon1_code"
        }
      )
      applied_coupon = customer.applied_coupons.active.first

      # Create wallet
      create_wallet(
        {
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet1",
          currency: "EUR",
          paid_credits: "10",
          granted_credits: "10",
          expiration_at: (Time.current + 15.days).iso8601
        }
      )
      wallet = customer.wallets.active.first

      delete_customer(customer)

      # Customer is discarded
      expect(customer.reload).to be_discarded

      perform_all_enqueued_jobs

      # Subscription is terminated
      expect(subscription.reload).to be_terminated

      # Pending subscription is canceled
      expect(pending_subscription.reload).to be_canceled

      # Applied coupon is terminated
      expect(applied_coupon.reload).to be_terminated

      # Wallet is terminated
      expect(wallet.reload).to be_terminated

      # A new termination invoice has been created
      expect(subscription.invoices.count).to eq(3)
      term_invoice = subscription.invoices.order(created_at: :desc).first
      expect(term_invoice).to be_finalized

      # Draft invoices are now finalized
      expect(dec_invoice.reload).to be_finalized
      expect(jan_invoice.reload).to be_finalized
    end
  end
end
