# frozen_string_literal: true

require "rails_helper"

describe "Delete Plan Scenarios" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }
  let(:plan) { create(:plan, pay_in_advance: true, organization:, amount_cents: 1000) }
  let(:metric) { create(:billable_metric, organization:) }

  it "deletes the plan, terminates subscriptions and finalizes draft invoices" do
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
      create(:plan, pay_in_advance: true, organization:, amount_cents: 1000, parent_id: plan.id)
    end

    subscription = customer.subscriptions.first
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
      overridden_plan = plan.children.first
      delete_with_token(organization, "/api/v1/plans/#{plan.code}")

      # Plan is pending deletion
      expect(plan.reload).to be_pending_deletion
      expect(overridden_plan.reload).to be_pending_deletion

      perform_all_enqueued_jobs

      # Plan is now discarded
      expect(plan.reload).not_to be_pending_deletion
      expect(overridden_plan.reload).not_to be_pending_deletion
      expect(plan).to be_discarded
      expect(overridden_plan).to be_discarded

      # Subscription is terminated
      expect(subscription.reload).to be_terminated

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
