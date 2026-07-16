# frozen_string_literal: true

require "rails_helper"

describe "Wallet target rule granting the top-up for free", :premium, transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, interval: "monthly", amount_cents: 0, pay_in_advance: false) }
  let(:billable_metric) { create(:billable_metric, organization:, field_name: "total", aggregation_type: "sum_agg") }
  let(:charge) { create(:standard_charge, plan:, billable_metric:, properties: {"amount" => "1"}) }

  before { charge }

  def ingest_event(subscription, amount)
    create_event({
      transaction_id: SecureRandom.uuid,
      code: billable_metric.code,
      external_subscription_id: subscription.external_id,
      properties: {billable_metric.field_name => amount}
    })
    perform_usage_update
  end

  context "when a target rule has grants_target_top_up enabled" do
    it "fills the gap as granted credits without charging the customer" do
      time_0 = DateTime.new(2024, 6, 1)
      wallet = nil

      travel_to time_0 do
        wallet = create_wallet({
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet#{SecureRandom.hex(4)}",
          currency: "EUR",
          granted_credits: "10",
          paid_top_up_min_amount_cents: 50_00,
          recurring_transaction_rules: [
            {
              trigger: "threshold",
              method: "target",
              threshold_credits: "5",
              target_ongoing_balance: "10",
              grants_target_top_up: true
            }
          ]
        }, as: :model)

        # The rule is exposed as granting the top-up over the REST response.
        rule = wallet.recurring_transaction_rules.sole
        expect(rule.grants_target_top_up).to be(true)

        create_subscription({
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code
        })
      end

      subscription = customer.subscriptions.sole

      travel_to time_0 + 5.days do
        # 6 credits of usage drops the ongoing balance to 4, below the threshold of 5.
        ingest_event(subscription, 6)
        recalculate_wallet_balances

        wallet.reload

        # The gap to the target (10 - 4 = 6) is granted for free, bypassing paid_top_up_min.
        top_up = wallet.wallet_transactions.where(source: "threshold").sole
        expect(top_up.transaction_type).to eq("inbound")
        expect(top_up.transaction_status).to eq("granted")
        expect(top_up.credit_amount).to eq(6)

        # Real balance grew from 10 to 16 with no invoice issued for the top-up.
        expect(wallet.credits_balance).to eq(16)
        expect(customer.invoices.count).to eq(0)
      end
    end
  end

  context "when a target rule keeps grants_target_top_up disabled" do
    it "fills the gap as a paid top-up subject to the minimum amount" do
      time_0 = DateTime.new(2024, 6, 1)
      wallet = nil

      travel_to time_0 do
        wallet = create_wallet({
          external_customer_id: customer.external_id,
          rate_amount: "1",
          name: "Wallet#{SecureRandom.hex(4)}",
          currency: "EUR",
          granted_credits: "10",
          paid_top_up_min_amount_cents: 50_00,
          recurring_transaction_rules: [
            {
              trigger: "threshold",
              method: "target",
              threshold_credits: "5",
              target_ongoing_balance: "10",
              grants_target_top_up: false
            }
          ]
        }, as: :model)

        rule = wallet.recurring_transaction_rules.sole
        expect(rule.grants_target_top_up).to be(false)

        create_subscription({
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code
        })
      end

      subscription = customer.subscriptions.sole

      travel_to time_0 + 5.days do
        ingest_event(subscription, 6)
        recalculate_wallet_balances

        wallet.reload

        # The gap (6) is below the paid minimum (50), so the paid top-up is raised to 50 credits.
        top_up = wallet.wallet_transactions.where(source: "threshold").sole
        expect(top_up.transaction_status).to eq("purchased")
        expect(top_up.credit_amount).to eq(50)
      end
    end
  end
end
