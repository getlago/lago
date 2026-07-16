# frozen_string_literal: true

require "rails_helper"

describe "Recurring fee invoice inclusion after upgrade" do
  let(:organization) { create(:organization, webhook_url: "http://lago.test/wh") }
  let(:customer) { create(:customer, organization:) }
  let(:billable_metric) { create(:sum_billable_metric, :recurring, organization:) }
  let(:original_plan) { create(:plan, organization:) }
  let(:upgraded_plan) { create(:plan, organization:) }
  let(:external_subscription_id) { SecureRandom.uuid }

  let(:charge) do
    create(
      :charge,
      plan: original_plan,
      billable_metric:,
      prorated: true,
      pay_in_advance: true,
      invoiceable: false,
      regroup_paid_fees: "invoice",
      properties: {amount: "1"}
    )
  end

  before do
    WebMock
      .stub_request(:post, "http://lago.test/wh")
      .to_return(status: 200, body: "", headers: {})

    charge
  end

  it "includes the recurring fee in the end-of-period invoice after subscription upgrade" do
    travel_to Time.zone.parse("2024-12-30T03:55:00") do
      # Step 1: Create a subscription with a start date in the past
      create_subscription(
        {external_customer_id: customer.external_id,
         external_id: external_subscription_id,
         plan_code: original_plan.code,
         subscription_at: 2.weeks.ago}
      )
      subscription = customer.subscriptions.first

      WebMock.reset_executed_requests!

      # Step 2: Send an event in the past and verify fee creation
      create_event(
        {transaction_id: SecureRandom.uuid,
         code: billable_metric.code,
         external_subscription_id: subscription.external_id,
         properties: {"item_id" => 1},
         timestamp: 1.week.ago.to_i}
      )

      fee_from_date = subscription.subscription_at.beginning_of_day.to_time.iso8601
      fee_to_date = subscription.subscription_at.end_of_month.to_time.iso8601

      expect(
        a_request(:post, "http://lago.test/wh")
        .with(
          body: hash_including(
            webhook_type: "fee.created", fee: hash_including(
              {
                "units" => "1.0",
                "from_date" => fee_from_date,
                "to_date" => fee_to_date
              }
            )
          )
        )
      ).to have_been_made.once

      fee = Fee.where(subscription:, charge:, created_at: Time.current.to_date..).sole
      expect(fee).to be_present

      # Step 3: Duplicate the original plan with a higher price
      upgraded_plan.update!(amount_cents: original_plan.amount_cents + 10_00)

      # Step 4: Upgrade the subscription to the new plan
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: external_subscription_id,
          plan_code: upgraded_plan.code
        }
      )

      # Step 5: Mark the original fee as succeeded
      update_fee(fee.id, {payment_status: "succeeded"})
      expect(fee.reload.payment_status).to eq("succeeded")

      # Step 6: Verify the fee is included in the end-of-period invoice
      terminate_subscription(subscription)

      fee_invoice = customer.invoices.find_by(invoice_type: "advance_charges")

      expect(fee_invoice).to be_present
      expect(fee_invoice.fees).to include(fee)
    end
  end
end
