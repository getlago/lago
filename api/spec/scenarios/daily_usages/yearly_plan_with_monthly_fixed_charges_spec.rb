# frozen_string_literal: true

require "rails_helper"

# Scenario: Yearly plan with bill_fixed_charges_monthly terminates mid-period
#
# Preconditions:
#   - Organization with premium feature 'revenue_analytics'
#   - Yearly plan with bill_fixed_charges_monthly: true and a fixed charge
#
# Steps:
#   1. Create subscription in a non-first month of the yearly period (March)
#   2. Terminate subscription
#
# Expected:
#   - Invoice is created with fixed charge fees only
#   - InvoiceSubscription has nil charges_from_datetime/charges_to_datetime
#     (no usage charges to bill in non-first month of yearly period)
#   - DailyUsages::FillFromInvoiceJob completes without error
#   - No DailyUsage record is created (no charge boundaries to record)
describe "Daily Usage for yearly plan with monthly fixed charges", :premium, cache: :redis do
  let(:organization) { create(:organization, webhook_url: nil, premium_integrations: %w[revenue_analytics]) }
  let(:customer) { create(:customer, external_id: "cust_yearly_fc", organization:) }
  let(:add_on) { create(:add_on, organization:, amount_cents: 2_499_00, amount_currency: "EUR") }

  let(:plan) do
    create(
      :plan,
      organization:,
      amount_cents: 0,
      amount_currency: "EUR",
      interval: "yearly",
      pay_in_advance: false,
      bill_fixed_charges_monthly: true
    )
  end

  let(:fixed_charge) do
    create(
      :fixed_charge,
      plan:,
      add_on:,
      units: 1,
      properties: {amount: "2499"}
    )
  end

  before { fixed_charge }

  it "does not fail when terminating subscription in non-first month of yearly period" do
    # Create subscription in March (non-first month for calendar yearly plan)
    travel_to(DateTime.new(2025, 3, 1)) do
      create_subscription({
        external_customer_id: customer.external_id,
        external_id: "sub_yearly_fc",
        plan_code: plan.code,
        billing_time: "calendar"
      })
    end

    subscription = customer.subscriptions.sole

    # Terminate subscription — triggers invoice with invoicing_reason: :subscription_terminating
    # The InvoiceSubscription will have nil charges_from_datetime/charges_to_datetime
    # because should_fill_charges_boundaries? returns false in non-first month
    travel_to(DateTime.new(2025, 3, 15)) do
      terminate_subscription(subscription)
    end

    # Verify invoice was created with fixed charge fees
    invoice = subscription.invoices.order(:created_at).last
    expect(invoice).to be_present
    expect(invoice.status).to eq("finalized")

    # Verify the invoice_subscription has nil charge boundaries
    invoice_subscription = invoice.invoice_subscriptions.first
    expect(invoice_subscription.charges_from_datetime).to be_nil
    expect(invoice_subscription.charges_to_datetime).to be_nil

    # Verify no daily usage was created (no charge boundaries to record)
    expect(DailyUsage.where(subscription:).count).to eq(0)
  end
end
