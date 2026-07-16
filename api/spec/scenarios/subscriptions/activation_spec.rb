# frozen_string_literal: true

require "rails_helper"

describe "Subscriptions Activation Scenario" do
  let(:organization) { create(:organization, webhook_url: nil) }

  let(:timezone) { "America/Bogota" }
  let(:customer) { create(:customer, organization:, timezone:) }

  let(:plan) do
    create(
      :plan,
      organization:,
      interval: "monthly",
      pay_in_advance: false
    )
  end

  # subscription_at must be on a different date than creation_time in the customer's timezone (America/Bogota, UTC-5)
  # creation_time: 2023-08-24 00:07 UTC → 2023-08-23 19:07 Bogota
  # subscription_at: 2023-08-25 10:00 UTC → 2023-08-25 05:00 Bogota (different day)
  let(:creation_time) { DateTime.new(2023, 8, 24, 0, 7) }
  let(:subscription_at) { DateTime.new(2023, 8, 25, 10, 0) }
  let(:fixed_charge) { create(:fixed_charge, plan:, pay_in_advance: true) }

  before { fixed_charge }

  it "activates the subscription when it reaches its subscription date" do
    subscription = nil

    travel_to(creation_time) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code,
          billing_time: "calendar",
          subscription_at: subscription_at.iso8601
        }
      )

      subscription = customer.subscriptions.first
      expect(subscription).to be_pending
    end

    travel_to(subscription_at) do
      Subscriptions::ActivateAllPendingService.call!(timestamp: Time.current.to_i)

      expect(subscription.reload).to be_active
    end
  end

  context "with activation rules on a future-dated subscription" do
    let(:pay_in_advance_plan) do
      create(:plan, organization:, interval: "monthly", pay_in_advance: true, amount_cents: 1000)
    end
    let(:stripe_provider) { create(:stripe_provider, organization:) }
    let(:stripe_customer) { create(:stripe_customer, payment_provider: stripe_provider, customer:) }
    let(:payment_method) { create(:payment_method, customer:) }

    before do
      create(:tax, :applied_to_billing_entity, organization:, rate: 0)
      customer.update!(payment_provider: :stripe, payment_provider_code: stripe_provider.code)
      stripe_customer
      payment_method

      allow_any_instance_of(::PaymentProviders::Stripe::Payments::CreateService) # rubocop:disable RSpec/AnyInstance
        .to receive(:create_payment_intent)
        .and_return(
          Stripe::PaymentIntent.construct_from(
            id: "pi_#{SecureRandom.hex(12)}",
            status: "processing",
            amount: 1000,
            currency: "eur"
          )
        )
    end

    it "stores rules as inactive, then evaluates and gates on activation date" do
      subscription = nil

      travel_to(creation_time) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: "gated-future-sub",
            plan_code: pay_in_advance_plan.code,
            billing_time: "calendar",
            subscription_at: subscription_at.iso8601,
            activation_rules: [{type: "payment", timeout_hours: 48}]
          }
        )

        subscription = customer.subscriptions.first
        expect(subscription).to be_pending
        expect(subscription.activation_rules.sole).to be_inactive
      end

      travel_to(subscription_at) do
        Subscriptions::ActivateAllPendingService.call!(timestamp: Time.current.to_i)
        perform_all_enqueued_jobs

        subscription.reload
        expect(subscription).to be_incomplete
        expect(subscription.activation_rules.sole).to be_pending
      end
    end
  end

  it "generates a pay in advance invoice for the fixed charge" do
    subscription = nil

    travel_to(creation_time) do
      create_subscription(
        {
          external_customer_id: customer.external_id,
          external_id: customer.external_id,
          plan_code: plan.code,
          billing_time: "calendar",
          subscription_at: subscription_at.iso8601
        }
      )

      subscription = customer.subscriptions.first
      expect(subscription).to be_pending
    end

    travel_to(subscription_at) do
      Subscriptions::ActivateAllPendingService.call!(timestamp: Time.current.to_i)
      perform_enqueued_jobs

      expect(subscription.reload).to be_active

      expect(subscription.invoices.count).to eq(1)
      expect(subscription.invoices.first.fees.count).to eq(1)
      expect(subscription.invoices.first.fees.first.fixed_charge.id).to eq(fixed_charge.id)
    end
  end
end
