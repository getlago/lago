# frozen_string_literal: true

require "rails_helper"

describe "Update Customer Invoice Grace Period Scenarios", :premium do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:, invoice_grace_period: 3) }
  let(:plan) { create(:plan, pay_in_advance: true, organization:) }

  before do
    stub_pdf_generation
  end

  it "updates the grace period of the customer" do
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
    end

    subscription = customer.subscriptions.find_by(external_id: customer.external_id)
    dec_invoice = subscription.invoices.first
    expect(dec_invoice).to be_draft

    ### 1 Jan: Billing
    jan1 = DateTime.new(2023, 1, 1)

    travel_to(jan1) do
      expect do
        create_or_update_customer(
          {
            external_id: customer.external_id,
            billing_configuration: {invoice_grace_period: 0}
          }
        )
      end.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(customer.reload.invoice_grace_period).to eq(0)
      expect(dec_invoice.reload).to be_finalized
    end
  end
end
