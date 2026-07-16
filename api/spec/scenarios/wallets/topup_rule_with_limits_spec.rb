# frozen_string_literal: true

require "rails_helper"

describe "Top up with wallet limits", :premium, transaction: false do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, amount_cents: 600, pay_in_advance: true) }

  context "when recurring rule has ignore limits enabled" do
    it "creates top up that exceeds wallet limits" do
      allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService).to receive(:create_payment_intent) # rubocop:disable RSpec/AnyInstance
        .and_return(
          Stripe::PaymentIntent.construct_from(
            id: "ch_#{SecureRandom.hex(6)}",
            status: :succeeded,
            amount: 1000,
            currency: "EUR"
          )
        )

      wallet = create_wallet({
        external_customer_id: customer.external_id,
        rate_amount: "1",
        name: "Wallet1",
        currency: "EUR",
        granted_credits: "10",
        paid_top_up_min_amount_cents: 100_00,
        recurring_transaction_rules: [
          {
            trigger: "threshold",
            paid_credits: "10",
            method: "fixed",
            threshold_credits: "5",
            ignore_paid_top_up_limits: true
          }
        ]
      }, as: :model)

      setup_stripe_for(customer:)

      subscription = nil
      travel_to(Time.zone.parse("2025-09-01T22:00:00")) do
        subscription = create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            interval: "calendar"
          }, as: :model
        )
      end

      expect(subscription.invoices.count).to eq 1

      invoice = subscription.invoices.sole

      expect(invoice.prepaid_credit_amount_cents).to eq(600)

      wallet.reload

      expect(wallet.credits_balance).to eq 14
    end
  end
end
