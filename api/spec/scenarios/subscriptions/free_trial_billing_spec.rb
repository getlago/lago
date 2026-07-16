# frozen_string_literal: true

require "rails_helper"

describe "Free Trial Billing Subscriptions Scenario" do
  let(:timezone) { "UTC" }
  let(:organization) { create(:organization, webhook_url: nil) }
  let(:billable_metric) { create(:billable_metric, organization:) }
  let(:customer) { create(:customer, organization:, timezone:) }
  let(:plan) do
    create(
      :plan,
      organization:,
      trial_period:,
      amount_cents: 5_000_000,
      pay_in_advance: true
    )
  end

  def create_customer_subscription!
    create(:standard_charge, plan:, billable_metric:, properties: {amount: "10"})
    create_subscription(
      {
        external_customer_id: customer.external_id,
        external_id: customer.external_id,
        plan_code: plan.code
      }
    )
  end

  def create_usage_event!
    create_event(
      {
        code: billable_metric.code,
        transaction_id: SecureRandom.uuid,
        external_subscription_id: customer.external_id
      }
    )
  end

  context "without free trial" do
    let(:trial_period) { 0 }

    it "bills the customer at the beginning of the subscription" do
      travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
        create_customer_subscription!
        expect(customer.reload.invoices.count).to eq(1)
        expect(customer.invoices.first.fees.subscription).to exist
      end
    end
  end

  context "with free trial" do
    let(:trial_period) { 10 }

    it "bills the customer at the end of the free trial" do
      travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
        create_customer_subscription!
        expect(customer.reload.invoices.count).to eq(0)
      end
      subscription = customer.subscriptions.sole

      # Ensure nothing happened
      travel_to(Time.zone.parse("2024-03-10T12:12:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(0)
      end

      # NOTE: The subscription was started at 12:12:00, so the trial period ends exactly at 12:12:00
      #       This ensure that Subscriptions::FreeTrialBillingService grabs subscriptions that
      #       ended in the last hour.
      travel_to(Time.zone.parse("2024-03-15T12:02:00")) do
        expect(subscription).to be_in_trial_period
        perform_billing
        expect(customer.reload.invoices.count).to eq(0)
      end

      travel_to(Time.zone.parse("2024-03-15T13:02:00")) do
        expect(subscription).not_to be_in_trial_period
        perform_billing
        expect(customer.reload.invoices.count).to eq(1)
        invoice = customer.reload.invoices.sole
        expect(invoice.fees.count).to eq(1)
        expect(invoice.fees.subscription.first.amount_cents).to eq(2_741_935) # (31 - 4 - 10) / 31 * 5000000 = 2741935
      end
    end

    # NOTE: This only happens if the customer was billed at the beginning of the free trial
    #       BEFORE the feature to bill at the end of the free trial was implemented
    it "does not bill the customer if it was already billed at the beginning of the trial" do
      travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
        create_customer_subscription!
        expect(customer.reload.invoices.count).to eq(0)

        plan.update! trial_period: 0 # disable trial to force billing
        BillSubscriptionJob.perform_now(customer.subscriptions.to_a, Time.current, invoicing_reason: :subscription_starting)
        expect(customer.reload.invoices.count).to eq(1)

        plan.update! trial_period: 10
      end

      # Ensure nothing happened
      travel_to(Time.zone.parse("2024-03-10T12:12:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(1)
      end

      travel_to(Time.zone.parse("2024-03-15T15:00:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(1)
      end

      travel_to(Time.zone.parse("2024-03-20T12:12:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(1)
      end
    end
  end

  context "with a plan upgrade during the trial" do
    let(:trial_period) { 10 }

    it "bills the subscription of the upgraded plan at the end of the trial" do
      travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
        create_customer_subscription!
        expect(customer.reload.invoices.count).to eq(0)
        perform_billing
        expect(customer.reload.invoices.count).to eq(0)
      end

      travel_to(Time.zone.parse("2024-03-08")) { create_usage_event! }

      # Upgrade to a new plan
      # It create an invoice with the old plan because there was some usage
      travel_to(Time.zone.parse("2024-03-10T12:12:00")) do
        upgrade_plan = create(:plan, organization:, trial_period: 13, amount_cents: 10_000_000, pay_in_advance: true)
        create(:standard_charge, plan: upgrade_plan, billable_metric:, properties: {amount: "12"})
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: upgrade_plan.code
          }
        )
        perform_billing
        expect(customer.reload.invoices.count).to eq(1)
        invoice = customer.invoices.sole
        expect(invoice.fees.count).to eq(1)
        expect(invoice.fees.charge.first.amount_cents).to eq(1000)
      end

      travel_to(Time.zone.parse("2024-03-11")) { create_usage_event! }

      # After plan.trial_period days, nothing happens
      travel_to(Time.zone.parse("2024-03-15T13:00:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(1)
      end

      # Using plan.started_at + upgrade_plan.trial_period days, the trial ends
      travel_to(Time.zone.parse("2024-03-18T13:00:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(2)
        invoice = customer.invoices.order(created_at: :desc).first
        expect(invoice.fees.count).to eq(1)
        expect(invoice.fees.subscription.first.amount_cents).to eq(4_516_129) # (31 - 4 - 13) / 31 * 10000000
      end

      travel_to(Time.zone.parse("2024-04-01T12:12:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(3)
        invoice = customer.invoices.order(created_at: :desc).first
        expect(invoice.fees.count).to eq(2)
        expect(invoice.fees.charge.first.amount_cents).to eq(1200)
        expect(invoice.fees.subscription.first.amount_cents).to eq(10_000_000)
      end
    end

    context "when the upgrade happens on day one" do
      it "bills the usage instantly and the subscription of the upgraded plan at the end of trial period" do
        travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
          create_customer_subscription!
          expect(customer.reload.invoices.count).to eq(0)
          perform_billing
          expect(customer.reload.invoices.count).to eq(0)
        end

        travel_to(Time.zone.parse("2024-03-05T13:00:00")) { create_usage_event! }

        # Upgrade to a new plan
        # It create an invoice with the old plan because there was some usage
        travel_to(Time.zone.parse("2024-03-05T13:15:00")) do
          upgrade_plan = create(:plan, organization:, trial_period: 13, amount_cents: 10_000_000, pay_in_advance: true)
          create(:standard_charge, plan: upgrade_plan, billable_metric:, properties: {amount: "12"})
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: upgrade_plan.code
            }
          )
          perform_billing
          expect(customer.reload.invoices.count).to eq(1)
          invoice = customer.invoices.sole
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.charge.first.amount_cents).to eq(1000)
        end

        travel_to(Time.zone.parse("2024-03-05T15:00:00")) { create_usage_event! }
        travel_to(Time.zone.parse("2024-03-05T15:01:00")) { create_usage_event! }

        # Using plan.started_at + upgrade_plan.trial_period days, the trial ends
        travel_to(Time.zone.parse("2024-03-18T13:00:00")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(2)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.subscription.first.amount_cents).to eq(4_516_129) # (31 - 4 - 13) / 31 * 10000000
        end

        travel_to(Time.zone.parse("2024-04-01T12:12:00")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(3)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(2)
          expect(invoice.fees.charge.first.amount_cents).to eq(2400)
          expect(invoice.fees.subscription.first.amount_cents).to eq(10_000_000)
        end
      end
    end

    context "with a grace period" do
      it "bills the usage instantly and the subscription of the upgraded plan at the end of trial period" do
        travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
          customer.update! invoice_grace_period: 2
          create_customer_subscription!
          expect(customer.reload.invoices.count).to eq(0)
          perform_billing
          expect(customer.reload.invoices.count).to eq(0)
        end

        travel_to(Time.zone.parse("2024-03-05T13:00:00")) { create_usage_event! }

        # Upgrade to a new plan
        # It create an invoice with the old plan because there was some usage
        travel_to(Time.zone.parse("2024-03-05T13:15:00")) do
          upgrade_plan = create(:plan, organization:, trial_period: 13, amount_cents: 10_000_000, pay_in_advance: true)
          create(:standard_charge, plan: upgrade_plan, billable_metric:, properties: {amount: "12"})
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: upgrade_plan.code
            }
          )
          perform_billing
          expect(customer.reload.invoices.count).to eq(1)
          invoice = customer.invoices.sole
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.charge.first.amount_cents).to eq(1000)
          expect(invoice.status).to eq("draft")
        end

        travel_to(Time.zone.parse("2024-03-07T18:00:00")) do
          Clock::FinalizeInvoicesJob.perform_later
          perform_all_enqueued_jobs

          invoice = customer.invoices.reload.sole
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.charge.first.amount_cents).to eq(1000)
          expect(invoice.status).to eq("finalized")
        end

        travel_to(Time.zone.parse("2024-03-05T15:00:00")) { create_usage_event! }
        travel_to(Time.zone.parse("2024-03-05T15:01:00")) { create_usage_event! }

        # Using plan.started_at + upgrade_plan.trial_period days, the trial ends
        travel_to(Time.zone.parse("2024-03-18T13:00:00")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(2)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.subscription.first.amount_cents).to eq(4_516_129) # (31 - 4 - 13) / 31 * 10000000
        end

        travel_to(Time.zone.parse("2024-04-01T12:12:00")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(3)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(2)
          expect(invoice.fees.charge.first.amount_cents).to eq(2400)
          expect(invoice.fees.subscription.first.amount_cents).to eq(10_000_000)
        end
      end
    end
  end

  context "with free trial > billing period" do
    let(:trial_period) { 45 }

    it "bills subscription at the end of the free trial" do
      travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
        create_customer_subscription!
        expect(customer.reload.invoices.count).to eq(0)
      end

      travel_to(Time.zone.parse("2024-03-10")) { create_usage_event! }

      travel_to(Time.zone.parse("2024-04-01")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(1)
        invoice = customer.invoices.sole
        expect(invoice.fees.count).to eq(1)
        expect(invoice.fees.charge.first.amount_cents).to eq(1000)
      end

      travel_to(Time.zone.parse("2024-04-19T13:01:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(2)
        free_trial_invoice = customer.invoices.order(created_at: :desc).first
        expect(free_trial_invoice.fees.count).to eq(1)
        expect(free_trial_invoice.fees.subscription.first.amount_cents).to eq(2_000_000) # 5_000_000 * 12 / 30
      end
    end

    context "with a grace period" do
      it "bills the customer at the end of the free trial but finalize after grace period" do
        travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
          customer.update! invoice_grace_period: 2
          create_customer_subscription!
          expect(customer.reload.invoices.count).to eq(0)
        end

        travel_to(Time.zone.parse("2024-03-10")) { create_usage_event! }

        travel_to(Time.zone.parse("2024-04-01")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(1)
          invoice = customer.invoices.sole
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.charge.first.amount_cents).to eq(1000)
        end

        travel_to(Time.zone.parse("2024-04-19T13:01:00")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(2)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.subscription.first.amount_cents).to eq(2_000_000) # 5_000_000 * 12 / 30
          expect(invoice.status).to eq("draft")
        end

        # Ensure charge fees are not added when refreshing the invoice
        travel_to(Time.zone.parse("2024-04-21T13:22:00")) do
          invoice = customer.invoices.order(created_at: :desc).first
          Invoices::RefreshDraftJob.perform_later(invoice:)
          perform_all_enqueued_jobs
          expect(customer.reload.invoices.count).to eq(2)
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.subscription.first.amount_cents).to eq(2_000_000)
          expect(invoice.status).to eq("draft")

          Clock::FinalizeInvoicesJob.perform_later
          perform_all_enqueued_jobs

          expect(customer.reload.invoices.count).to eq(2)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.subscription.first.amount_cents).to eq(2_000_000)
          expect(invoice.status).to eq("finalized")
        end
      end
    end

    context "with a plan with minimum commitment" do
      it "bills minimum commitment on billing day, despite being in trial" do
        travel_to(Time.zone.parse("2024-03-05T12:12:00")) do
          create(:commitment, :minimum_commitment, plan:, amount_cents: 10_000_000)
          create_customer_subscription!
          expect(customer.reload.invoices.count).to eq(0)
        end

        travel_to(Time.zone.parse("2024-03-10")) { create_usage_event! }

        travel_to(Time.zone.parse("2024-04-01")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(1)
          invoice = customer.invoices.sole
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.charge.first.amount_cents).to eq(1000)
        end

        travel_to(Time.zone.parse("2024-04-10")) { create_usage_event! }

        travel_to(Time.zone.parse("2024-04-19T13:01:00")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(2)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.subscription.first.amount_cents).to eq(2_000_000) # 5_000_000 * 12 / 30
        end

        travel_to(Time.zone.parse("2024-05-01")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(3)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(3)
          expect(invoice.fees.subscription.first.amount_cents).to eq(5_000_000)
          expect(invoice.fees.charge.first.amount_cents).to eq(1000)
          # The minimum commitment true up look at usage in previous month,
          # when the trial ended and the customer paid only 2_000_000 in subscription fee
          expect(invoice.fees.commitment.first.amount_cents).to eq(10_000_000 - 2_000_000 - 1000)
        end
      end
    end
  end

  context "with free trial ending on billing day" do
    let(:trial_period) { 10 }
    let(:timezone) { "Europe/Paris" }

    it "bills subscription and usage-based charges" do
      start_time = Time.zone.parse("2024-03-22T01:12:00")
      travel_to(start_time) do
        create_customer_subscription!
        expect(customer.reload.invoices.count).to eq(0)
      end

      travel_to(Time.zone.parse("2024-03-23")) { create_usage_event! }

      expect(customer.reload.invoices.count).to eq(0)

      # NOTE: Subscriptions::OrganizationBillingService will bill the subscription because it's billing day
      #       Subscriptions::FreeTrialBillingService will ignore it because the trial ends at 12:12:00
      #
      #   Time.current:                         31 Mar 2024 22:01:00 UTC +00:00
      #   Time.current.in_time_zone(timezone):  01 Apr 2024 00:01:00 CEST +02:00
      #   sub.trial_end_datetime:               01 Apr 2024 01:12:00 UTC +00:00
      billing_day = Time.parse("2024-04-01T00:01:00").in_time_zone(timezone)
      travel_to(billing_day) do
        perform_billing
        invoice = customer.invoices.order(created_at: :desc).sole
        expect(invoice.fees.subscription.first.amount_cents).to eq(5_000_000) # full fee, trial is over
        expect(invoice.fees.charge.first.amount_cents).to eq(1000)
      end

      # NOTE: After the trial ends, we don't invoice again because it was done above
      #       but we terminate the trial and send the webhook
      travel_to(Time.zone.parse("2024-04-01T13:11:00")) do
        perform_billing
        expect(customer.reload.invoices.count).to eq(1)
        expect(customer.subscriptions.sole.trial_ended_at).to match_datetime(start_time + trial_period.days)
      end
    end

    context "with customer with a timezone" do
      let(:trial_period) { 10 }
      let(:timezone) { "Asia/Tokyo" }

      it "follows customer timezone for billing" do
        # Trial ends on April 1st, 2024 in UTC
        # but April 2nd, 2024 in Asia/Tokyo
        start_time = Time.parse("2024-03-22T18:12:00 UTC").in_time_zone(timezone)
        travel_to(start_time) do
          create_customer_subscription!
          expect(customer.reload.invoices.count).to eq(0)
        end

        travel_to(Time.zone.parse("2024-03-28")) { create_usage_event! }

        expect(customer.reload.invoices.count).to eq(0)

        # NOTE: Billing day in Asia/Tokyo
        travel_to(Time.parse("2024-03-31T15:10:00 UTC")) do # 2024-04-01T00:10:00 Asia/Tokyo
          perform_billing
          invoice = customer.invoices.order(created_at: :desc).sole
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.charge.first.amount_cents).to eq(1000)
        end

        # April 1st in both timezone, nothing should happen
        travel_to(Time.parse("2024-04-01T13:11:00 UTC")) do
          perform_billing
          expect(customer.reload.invoices.count).to eq(1)
        end

        travel_to(Time.parse("2024-04-01T19:11:00 UTC")) do # April 2nd, 2024 04:11:00 Asia/Tokyo, trial ended
          perform_billing
          expect(customer.reload.invoices.count).to eq(2)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.subscription.first.amount_cents).to eq(4_833_333) # Trial ends on the 2nd in customer tz
        end
      end
    end

    context "with SubscriptionsBillerJob running after FreeTrialSubscriptionsBillerJob" do
      it "bills subscription and usage-based charges" do
        start_time = Time.zone.parse("2024-03-22T12:12:00")
        travel_to(start_time) do
          create_customer_subscription!
          expect(customer.reload.invoices.count).to eq(0)
        end

        travel_to(Time.zone.parse("2024-03-23")) { create_usage_event! }

        expect(customer.reload.invoices.count).to eq(0)

        travel_to(Time.zone.parse("2024-04-01T13:01:00")) do
          Clock::FreeTrialSubscriptionsBillerJob.perform_later
          perform_all_enqueued_jobs

          invoice = customer.invoices.order(created_at: :desc).sole
          expect(customer.subscriptions.sole.trial_ended_at).to match_datetime(start_time + trial_period.days)
          # NOTE: The charge are not billed because FreeTrialBillingService use `skip_charges: true`
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.subscription.first.amount_cents).to eq(5_000_000) # full fee, trial is over
        end

        # NOTE: A new invoice is created because the end of trial invoice is created with `recurring: false`
        #       Only the usage-based is charged because subscription was already billed
        #       see Invoices::CalculateFeesService.should_create_subscription_fee?
        travel_to(Time.zone.parse("2024-04-01T15:11:00")) do
          Clock::SubscriptionsBillerJob.perform_later
          perform_all_enqueued_jobs

          expect(customer.reload.invoices.count).to eq(2)
          invoice = customer.invoices.order(created_at: :desc).first
          expect(invoice.fees.count).to eq(1)
          expect(invoice.fees.charge.sole.amount_cents).to eq(1000)
        end
      end
    end
  end
end
