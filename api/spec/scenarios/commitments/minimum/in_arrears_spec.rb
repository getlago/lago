# frozen_string_literal: true

require "rails_helper"

describe "Billing Minimum Commitments In Arrears Scenario" do
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:timezone) { "UTC" }
  let(:customer) { create(:customer, organization:, timezone:, currency: "EUR") }

  let(:plan) do
    create(
      :plan,
      organization:,
      amount_cents: 100_000,
      amount_currency: "EUR",
      interval: plan_interval,
      pay_in_advance: false,
      bill_charges_monthly:
    )
  end

  let(:bill_charges_monthly) { false }
  let(:invoice) { subscription.reload.invoices.first }
  let(:subscription) { customer.subscriptions.first.reload }

  before do
    minimum_commitment

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
    end

    billing_times.each do |time|
      travel_to(time) do
        perform_billing
      end
    end
  end

  shared_examples "a subscription billing" do
    context "when plan has no minimum commitment" do
      let(:minimum_commitment) { nil }

      it "creates an invoice without minimum commitment fee" do
        expect(invoice.fees.commitment.count).to eq(0)
      end
    end

    context "when minimum commitment amount is reached" do
      let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1) }

      it "creates an invoice without minimum commitment fee" do
        expect(invoice.fees.commitment.count).to eq(0)
      end
    end

    context "when minimum commitment amount is not reached" do
      let(:minimum_commitment) { create(:commitment, :minimum_commitment, plan:, amount_cents: 1_000_000) }

      it "creates an invoice with minimum commitment fee" do
        expect(invoice.fees.commitment.count).to eq(1)
        expect(invoice.fees.commitment.first.amount_cents).to eq(commitment_fee_amount_cents)
      end
    end
  end

  context "when plan is billed in arrears" do
    context "with weekly plan" do
      let(:plan_interval) { "weekly" }

      context "with calendar billing" do
        let(:billing_time) { "calendar" }
        let(:subscription_time) { DateTime.new(2023, 2, 1) }
        let(:billing_times) { [DateTime.new(2023, 2, 6, 1), DateTime.new(2023, 2, 6, 2)] }
        let(:commitment_fee_amount_cents) { 642_857 }

        it_behaves_like "a subscription billing"
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }
        let(:subscription_time) { DateTime.new(2023, 2, 1) }
        let(:billing_times) { [DateTime.new(2023, 2, 15, 1), DateTime.new(2023, 2, 15, 2)] }
        let(:commitment_fee_amount_cents) { 900_000 }

        it_behaves_like "a subscription billing"
      end
    end

    context "with monthly plan" do
      let(:plan_interval) { "monthly" }

      context "with calendar billing" do
        let(:billing_time) { "calendar" }
        let(:subscription_time) { DateTime.new(2023, 2, 4) }
        let(:billing_times) { [DateTime.new(2023, 3, 1, 1), DateTime.new(2023, 3, 1, 2)] }
        let(:commitment_fee_amount_cents) { 803_571 }

        it_behaves_like "a subscription billing"
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }
        let(:subscription_time) { DateTime.new(2023, 2, 4) }
        let(:billing_times) { [DateTime.new(2023, 3, 4, 1), DateTime.new(2023, 3, 4, 2)] }
        let(:commitment_fee_amount_cents) { 900_000 }

        it_behaves_like "a subscription billing"
      end
    end

    context "with quarterly plan" do
      let(:plan_interval) { "quarterly" }

      context "with calendar billing" do
        let(:billing_time) { "calendar" }
        let(:subscription_time) { DateTime.new(2023, 2, 4) }
        let(:billing_times) { [DateTime.new(2023, 4, 1, 1), DateTime.new(2023, 4, 1, 2)] }
        let(:commitment_fee_amount_cents) { 560_000 }

        it_behaves_like "a subscription billing"
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }
        let(:subscription_time) { DateTime.new(2023, 2, 4) }
        let(:billing_times) { [DateTime.new(2023, 5, 4, 1), DateTime.new(2023, 5, 4, 2)] }
        let(:commitment_fee_amount_cents) { 900_000 }

        it_behaves_like "a subscription billing"
      end
    end

    context "with yearly plan and yearly charge" do
      let(:plan_interval) { "yearly" }

      context "with calendar billing" do
        let(:billing_time) { "calendar" }
        let(:subscription_time) { DateTime.new(2022, 2, 1) }
        let(:billing_times) { [DateTime.new(2023, 1, 1, 1), DateTime.new(2023, 1, 1, 2)] }
        let(:commitment_fee_amount_cents) { 823_561 }

        it_behaves_like "a subscription billing"

        context "when plan is charged monthly" do
          let(:bill_charges_monthly) { false }

          it_behaves_like "a subscription billing"
        end
      end

      context "with anniversary billing" do
        let(:billing_time) { "anniversary" }
        let(:subscription_time) { DateTime.new(2022, 2, 4) }
        let(:billing_times) { [DateTime.new(2023, 2, 4, 1), DateTime.new(2023, 2, 4, 2)] }
        let(:commitment_fee_amount_cents) { 900_000 }

        context "when plan is charged yearly" do
          it_behaves_like "a subscription billing"
        end

        context "when plan is charged monthly" do
          let(:bill_charges_monthly) { false }

          it_behaves_like "a subscription billing"
        end
      end
    end
  end
end
