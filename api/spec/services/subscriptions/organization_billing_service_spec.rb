# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::OrganizationBillingService do
  subject(:billing_service) { described_class.new(organization:, billing_at:) }

  describe ".call" do
    let(:billing_entity_timezone) { "UTC" }
    let(:billing_entity) { create(:billing_entity, timezone: billing_entity_timezone) }
    let(:organization) { billing_entity.organization }

    let(:interval) { :monthly }
    let(:bill_charges_monthly) { false }
    let(:plan) { create(:plan, organization:, interval:, bill_charges_monthly:) }

    let(:customer_timezone) { nil }
    let(:customer) { create(:customer, organization:, billing_entity: billing_entity, timezone: customer_timezone) }

    let(:created_at) { DateTime.parse("20 Feb 2020") }
    let(:subscription_at) { DateTime.parse("20 Feb 2021") }
    let(:started_at) { DateTime.parse("10 Jun 2022") }
    let(:current_date) { DateTime.parse("20 Jun 2022 12:00") }
    let(:billing_at) { current_date }
    let(:ending_at) { nil }
    let(:billing_time) { :calendar }
    let(:subscription) do
      create(
        :subscription,
        customer: customer,
        plan:,
        subscription_at:,
        started_at:,
        billing_time:,
        created_at:,
        ending_at:
      )
    end

    before { subscription }

    def expect_to_bill_together(subscriptions, date)
      expect(BillSubscriptionJob).to have_been_enqueued
        .with(subscriptions, date.to_i, invoicing_reason: :subscription_periodic)
      expect(BillNonInvoiceableFeesJob).to have_been_enqueued
        .with(subscriptions, date)
    end

    [
      {interval: :weekly, billing_time: :calendar, billed_on: ["20 Jun 2022", "27 Jun 2022", "04 Jul 2022"]},
      {interval: :weekly, billing_time: :anniversary, billed_on: ["25 Jun 2022", "02 Jul 2022", "09 Jul 2022"]},
      {interval: :monthly, billing_time: :calendar, billed_on: ["01 Jul 2022", "01 Aug 2022", "01 Sep 2022"]},
      {interval: :monthly, billing_time: :anniversary, billed_on: ["20 Jun 2022", "20 Jul 2022", "20 Aug 2022"]},
      # 31st day monthly subscription (month normalization)
      {
        interval: :monthly,
        billing_time: :anniversary,
        subscription_at: "31 March 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Apr 2023", "31 Jan 2023"]
      },
      {
        interval: :quarterly,
        billing_time: :calendar,
        billed_on: ["01 Jul 2022", "01 Oct 2022", "01 Jan 2023", "01 Apr 2030"],
        not_billed_on: ["01 Feb 2022", "01 Mar 2022", "01 Dec 2023"]
      },
      # Quarterly cycle: Aug/Nov/Feb/May
      {
        interval: :quarterly,
        billing_time: :anniversary,
        billed_on: ["20 Aug 2022", "20 Nov 2022", "20 Feb 2023", "20 May 2030"],
        not_billed_on: ["20 Sep 2022"]
      },
      # Quarterly cycle: Jan/Apr/Jul/Oct
      {
        interval: :quarterly,
        billing_time: :anniversary,
        subscription_at: "15 January 2021",
        billed_on: ["15 Jul 2022", "15 Oct 2022", "15 Jan 2023", "15 Apr 2024"]
      },
      # Quarterly cycle: Mar/Jun/Sep/Dec
      {
        interval: :quarterly,
        billing_time: :anniversary,
        subscription_at: "15 March 2021",
        billed_on: ["15 Jun 2022", "15 Sep 2022", "15 Dec 2022", "15 Mar 2023"]
      },
      # 31st day quarterly subscription (month normalization)
      {
        interval: :quarterly,
        billing_time: :anniversary,
        subscription_at: "31 May 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Nov 2023", "31 Aug 2023"],
        not_billend_on: ["31 Aug 2023"]
      },
      # 30th day quarterly subscription (month normalization)
      {
        interval: :quarterly,
        billing_time: :anniversary,
        subscription_at: "30 May 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Nov 2023", "30 Aug 2023"],
        not_billend_on: ["31 Aug 2023"]
      },
      # Quarterly with monthly charges is not implemented
      # {
      #   interval: :quarterly,
      #   billing_time: :calendar,
      #   bill_charges_monthly: true,
      #   billed_on: ["01 Aug 2022",],
      #   not_billed_on: ["02 Aug 2022",],
      # },
      # {
      #   interval: :quarterly,
      #   billing_time: :anniversary,
      #   bill_charges_monthly: true,
      #   billed_on: ["20 Jul 2022",],
      #   not_billed_on: ["21 Jul 2022",],
      # },
      {
        interval: :semiannual,
        billing_time: :calendar,
        billed_on: ["01 Jul 2022", "01 Jan 2023", "01 Jul 2030"],
        not_billed_on: ["01 Oct 2022"]
      },
      {
        interval: :semiannual,
        billing_time: :anniversary,
        billed_on: ["20 Aug 2022", "20 Feb 2023", "20 Aug 2030"],
        not_billed_on: ["20 Nov 2022"]
      },
      # 31st day semiannual subscription (month normalization)
      {
        interval: :semiannual,
        billing_time: :anniversary,
        subscription_at: "31 Aug 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "31 Aug 2023"]
      },
      # 30th day semiannual subscription (month normalization)
      {
        interval: :semiannual,
        billing_time: :anniversary,
        subscription_at: "30 Aug 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Aug 2023"],
        not_billed_on: ["31 Aug 2023"]
      },
      {
        interval: :semiannual,
        billing_time: :calendar,
        bill_charges_monthly: true,
        billed_on: ["01 Aug 2022"],
        not_billed_on: ["02 Aug 2022"]
      },
      {
        interval: :semiannual,
        billing_time: :anniversary,
        bill_charges_monthly: true,
        billed_on: ["20 Jul 2022"],
        not_billed_on: ["21 Jul 2022"]
      },
      # 31st day semiannual subscription (month normalization)
      {
        interval: :semiannual,
        billing_time: :anniversary,
        bill_charges_monthly: true,
        subscription_at: "31 Aug 2021",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "30 Jun 2022", "31 Jul 2022"]
      },
      {
        interval: :yearly,
        billing_time: :calendar,
        billed_on: ["01 Jan 2023", "01 Jan 2024", "01 Jan 2030"],
        not_billed_on: ["01 Feb 2023", "01 Dec 2022"]
      },
      {
        interval: :yearly,
        billing_time: :anniversary,
        billed_on: ["20 Feb 2023", "20 Feb 2024", "20 Feb 2030"],
        not_billed_on: ["20 Jan 2023", "20 Mar 2023"]
      },
      # Non-leap year Feb 28 subscription
      {
        interval: :yearly,
        billing_time: :anniversary,
        subscription_at: "28 Feb 2021",
        billed_on: ["28 Feb 2023", "28 Feb 2024", "28 Feb 2030"],
        not_billed_on: ["29 Feb 2024"]
      },
      # Leap year Feb 29 subscription
      {
        interval: :yearly,
        billing_time: :anniversary,
        subscription_at: "29 Feb 2020",
        billed_on: ["28 Feb 2023", "29 Feb 2024", "28 Feb 2030"]
      },
      {
        interval: :yearly,
        billing_time: :calendar,
        bill_charges_monthly: true,
        billed_on: ["01 Aug 2022", "01 Sep 2022", "01 Oct 2022"],
        not_billed_on: ["02 Aug 2022", "31 Aug 2022"]
      },
      {
        interval: :yearly,
        billing_time: :anniversary,
        bill_charges_monthly: true,
        billed_on: ["20 Jul 2022", "20 Aug 2022", "20 Sep 2022"],
        not_billed_on: ["21 Jul 2022", "19 Jul 2022"]
      }
    ].each do |test_case|
      subscription_at = DateTime.parse(test_case[:subscription_at] || "20 Feb 2021")
      interval = test_case[:interval]
      billing_time = test_case[:billing_time] || :calendar
      not_billed_on = test_case.fetch(:not_billed_on, []).map { DateTime.parse(it) }
      billed_on = test_case[:billed_on].map { DateTime.parse(it) }
      focus = test_case.fetch(:focus, false)
      bill_charges_monthly = test_case.fetch(:bill_charges_monthly, false)

      context "when billed #{interval} with #{billing_time} billing time#{" with monthly charges" if bill_charges_monthly}", focus: do
        let(:interval) { interval }
        let(:billing_time) { billing_time }
        let(:bill_charges_monthly) { bill_charges_monthly }

        context "when subscribed on #{subscription_at.to_formatted_s(:long)}" do
          let(:subscription_at) { subscription_at }

          billed_on.each do |billed_on|
            is_31st = subscription_at.day == 31
            context "when on billing day#{" (31st)" if is_31st} (#{billed_on.to_formatted_s(:long)})" do
              let(:billing_at) { billed_on }

              it "enqueues a job" do
                billing_service.call

                expect_to_bill_together([subscription], billing_at)
              end
            end
          end

          not_billed_on.each do |not_billed_on|
            context "when billing on #{not_billed_on.to_formatted_s(:long)}" do
              let(:billing_at) { not_billed_on }

              it "does not bill" do
                expect { billing_service.call }.not_to have_enqueued_job
              end
            end
          end

          context "when multiple subscriptions are to be billed on the same day" do
            let(:billing_at) { billed_on.first }

            let(:monthly_subscription) do
              at = billing_at - 1.month
              create(
                :subscription,
                customer: customer,
                plan: create(:plan, organization:, interval: :monthly),
                subscription_at: at,
                started_at: at,
                billing_time: :anniversary,
                created_at: at
              )
            end

            let(:customer_with_weekly_billing) { create(:customer, organization:) }
            let(:subscription_with_weekly_billing) do
              at = billing_at - 1.week
              create(
                :subscription,
                customer: customer_with_weekly_billing,
                plan: create(:plan, organization:, interval: :weekly),
                subscription_at: at,
                started_at: at,
                billing_time: :anniversary,
                created_at: at
              )
            end

            let(:not_billed_customer) { create(:customer, organization:) }
            let(:not_billed_subscription) do
              at = billing_at - 1.week - 1.day
              create(
                :subscription,
                customer: not_billed_customer,
                plan: create(:plan, organization:, interval: :weekly),
                subscription_at: at,
                started_at: at,
                billing_time: :anniversary,
                created_at: at
              )
            end

            before do
              monthly_subscription
              subscription_with_weekly_billing
              not_billed_subscription
            end

            it "enqueues jobs for all customers" do
              billing_service.call

              expect_to_bill_together(contain_exactly(subscription, monthly_subscription), billing_at)

              expect_to_bill_together([subscription_with_weekly_billing], billing_at)

              expect(BillSubscriptionJob).not_to have_been_enqueued.with([not_billed_subscription], anything, invoicing_reason: :subscription_periodic)
            end
          end
        end

        context "when ending_at is the same as billing day" do
          let(:billing_at) { billed_on.first }
          let(:ending_at) { billing_at }

          it "does not bill" do
            expect { billing_service.call }.not_to have_enqueued_job
          end
        end

        context "when subscription started on billing day" do
          let(:started_at) { billed_on.first }

          it "does not bill" do
            expect { billing_service.call }.not_to have_enqueued_job
          end
        end

        context "when subscription starts after billing day" do
          let(:started_at) { billed_on.first + 1.day }

          it "does not bill" do
            expect { billing_service.call }.not_to have_enqueued_job
          end
        end

        context "when it is not yet billing day on customer timezone" do
          let(:subscription_at) { DateTime.parse("20 Feb 2021 12:00") }
          let(:billing_at) { billed_on.first }
          let(:customer_timezone) { "America/Chicago" }

          it "does not bill" do
            expect { billing_service.call }.not_to have_enqueued_job
          end
        end

        context "when it is after billing day on customer timezone" do
          let(:billing_at) { billed_on.first + 18.hours }
          let(:customer_timezone) { "Pacific/Auckland" }

          it "does not bill" do
            expect { billing_service.call }.not_to have_enqueued_job
          end
        end

        context "when it is not yet billing day on billing entity timezone" do
          let(:subscription_at) { DateTime.parse("20 Feb 2021 12:00") }
          let(:billing_at) { billed_on.first }
          let(:billing_entity_timezone) { "America/Chicago" }

          it "does not bill" do
            expect { billing_service.call }.not_to have_enqueued_job
          end
        end

        context "when it is after billing day on billing entity timezone" do
          let(:billing_at) { billed_on.first + 18.hours }
          let(:billing_entity_timezone) { "Pacific/Auckland" }

          it "does not bill" do
            expect { billing_service.call }.not_to have_enqueued_job
          end
        end
      end
    end

    context "when downgraded" do
      let(:subscription) do
        create(
          :subscription,
          customer:,
          subscription_at:,
          started_at: current_date - 10.days,
          previous_subscription:,
          status: :pending,
          created_at:
        )
      end

      let(:previous_subscription) do
        create(
          :subscription,
          customer:,
          subscription_at:,
          started_at: current_date - 10.days,
          billing_time: :anniversary,
          created_at:
        )
      end

      before { subscription }

      it "enqueues a job on billing day" do
        billing_service.call

        expect(Subscriptions::TerminateJob).to have_been_enqueued
          .with(previous_subscription, current_date.to_i)
      end

      context "when all customer subscriptions are downgraded" do
        it "does not enqueue billing jobs for that customer" do
          billing_service.call

          expect(BillSubscriptionJob).not_to have_been_enqueued
          expect(BillNonInvoiceableFeesJob).not_to have_been_enqueued
        end
      end
    end

    context "when on subscription creation day" do
      let(:created_at) { subscription_at }

      it "does not enqueue a job" do
        expect { billing_service.call }.not_to have_enqueued_job
      end
    end

    context "when subscription was already automatically billed today" do
      let(:invoice_subscription) do
        create(
          :invoice_subscription,
          subscription:,
          invoicing_reason: :subscription_periodic,
          timestamp: billing_at - 1.hour,
          recurring: true
        )
      end

      before { invoice_subscription }

      it "does not enqueue a job" do
        expect { billing_service.call }.not_to have_enqueued_job
      end
    end

    context "when grouping subscriptions by currency" do
      let(:organization) { create(:organization, feature_flags: ["multi_currency"]) }
      let(:interval) { :monthly }
      let(:billing_time) { :anniversary }
      let(:current_date) { subscription_at.next_month }

      before { subscription.destroy }

      context "when subscriptions have different currencies" do
        let(:usd_plan) { create(:plan, organization:, interval:, amount_currency: "USD") }
        let(:eur_plan) { create(:plan, organization:, interval:, amount_currency: "EUR") }

        let(:usd_subscription) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:eur_subscription) do
          create(
            :subscription,
            customer:,
            plan: eur_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end

        before do
          usd_subscription
          eur_subscription
        end

        it "produces separate billing jobs per currency" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([usd_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([eur_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([usd_subscription], current_date)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([eur_subscription], current_date)
        end

        context "without feature flag" do
          let(:organization) { create(:organization) }

          it "groups them into a single billing job" do
            billing_service.call

            expect(BillSubscriptionJob).to have_been_enqueued
              .with(
                contain_exactly(usd_subscription, eur_subscription),
                current_date.to_i,
                invoicing_reason: :subscription_periodic
              )
          end
        end
      end

      context "when subscriptions share the same currency" do
        let(:plan1) { create(:plan, organization:, interval:, amount_currency: "USD") }
        let(:plan2) { create(:plan, organization:, interval:, amount_currency: "USD") }

        let(:subscription1) do
          create(
            :subscription,
            customer:,
            plan: plan1,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:subscription2) do
          create(
            :subscription,
            customer:,
            plan: plan2,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end

        before do
          subscription1
          subscription2
        end

        it "groups them into a single billing job" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(
              contain_exactly(subscription1, subscription2),
              current_date.to_i,
              invoicing_reason: :subscription_periodic
            )
        end
      end

      context "when combined with payment method grouping" do
        let(:organization) { create(:organization, feature_flags: %w[multi_currency]) }
        let(:usd_plan) { create(:plan, organization:, interval:, amount_currency: "USD") }
        let(:eur_plan) { create(:plan, organization:, interval:, amount_currency: "EUR") }

        let(:usd_provider_subscription) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:usd_manual_subscription) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "manual"
          )
        end
        let(:eur_provider_subscription) do
          create(
            :subscription,
            customer:,
            plan: eur_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end

        before do
          usd_provider_subscription
          usd_manual_subscription
          eur_provider_subscription
        end

        it "produces separate billing jobs per payment method and currency" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([usd_provider_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([usd_manual_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([eur_provider_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
        end
      end
    end

    context "when grouping subscriptions by payment method" do
      let(:organization) { create(:organization) }
      let(:interval) { :monthly }
      let(:billing_time) { :anniversary }
      let(:current_date) { subscription_at.next_month }

      before { subscription.destroy }

      context "when customer has multiple subscriptions with same payment method type (provider)" do
        let(:customer3) { create(:customer, organization:) }
        let(:subscription1) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:subscription2) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:subscription3) do
          create(
            :subscription,
            customer: customer3,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end

        before do
          subscription1
          subscription2
          subscription3
        end

        it "groups them into a single billing job for a customer" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(
              contain_exactly(subscription1, subscription2),
              current_date.to_i,
              invoicing_reason: :subscription_periodic
            )
          expect(BillSubscriptionJob).to have_been_enqueued
            .with(
              [subscription3],
              current_date.to_i,
              invoicing_reason: :subscription_periodic
            )
        end
      end

      context "when customer has subscriptions with different payment method types" do
        let(:subscription1) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:subscription2) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "manual"
          )
        end

        before do
          subscription1
          subscription2
        end

        it "groups them into separate billing jobs" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription1], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription2], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([subscription1], current_date)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([subscription2], current_date)
        end
      end

      context "when subscriptions have different explicit payment_method_ids" do
        let(:customer3) { create(:customer, organization:) }
        let(:payment_method1) { create(:payment_method, customer:, organization:, is_default: true) }
        let(:payment_method2) { create(:payment_method, customer:, organization:, is_default: false, provider_method_id: "ext_456") }

        let(:subscription1) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method: payment_method1,
            payment_method_type: "provider"
          )
        end
        let(:subscription2) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method: payment_method2,
            payment_method_type: "provider"
          )
        end
        let(:subscription3) do
          create(
            :subscription,
            customer: customer3,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end

        before do
          subscription1
          subscription2
          subscription3
        end

        it "groups them into separate billing jobs" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription1], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription2], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription3], current_date.to_i, invoicing_reason: :subscription_periodic)
        end
      end

      context "when subscription with nil payment_method_id resolves to same as explicit one" do
        let(:payment_method) { create(:payment_method, customer:, organization:, is_default: true) }

        let(:subscription1) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method: payment_method,
            payment_method_type: "provider"
          )
        end
        let(:subscription2) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method: nil,
            payment_method_type: "provider"
          )
        end

        before do
          subscription1
          subscription2
        end

        it "groups them into a single billing job" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(
              contain_exactly(subscription1, subscription2),
              current_date.to_i,
              invoicing_reason: :subscription_periodic
            )
        end
      end

      context "when customer has default payment method" do
        let(:payment_method) { create(:payment_method, customer:, organization:, is_default: true) }

        let(:subscription1) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method: nil,
            payment_method_type: "provider"
          )
        end
        let(:subscription2) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method: nil,
            payment_method_type: "provider"
          )
        end

        before do
          subscription1
          subscription2
        end

        it "groups them into a single billing job" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(
              contain_exactly(subscription1, subscription2),
              current_date.to_i,
              invoicing_reason: :subscription_periodic
            )
        end
      end

      context "when single subscription exists" do
        let(:subscription1) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end

        before { subscription1 }

        it "returns single group without grouping logic" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription1], current_date.to_i, invoicing_reason: :subscription_periodic)
        end
      end
    end

    context "when grouping subscriptions by billing entity" do
      let(:organization) { create(:organization, feature_flags: ["multi_entity_billing"]) }
      let(:billing_entity) { create(:billing_entity, organization:) }
      let(:other_billing_entity) { create(:billing_entity, organization:) }
      let(:interval) { :monthly }
      let(:billing_time) { :anniversary }
      let(:current_date) { subscription_at.next_month }

      before { subscription.destroy }

      context "when subscriptions have different billing entities" do
        let(:subscription_default_entity) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:subscription_other_entity) do
          create(
            :subscription,
            customer:,
            plan:,
            billing_entity: other_billing_entity,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end

        before do
          subscription_default_entity
          subscription_other_entity
        end

        it "produces separate billing jobs per billing entity" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription_default_entity], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription_other_entity], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([subscription_default_entity], current_date)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([subscription_other_entity], current_date)
        end

        context "without feature flag" do
          let(:organization) { create(:organization) }

          it "groups them into a single billing job" do
            billing_service.call

            expect(BillSubscriptionJob).to have_been_enqueued
              .with(
                contain_exactly(subscription_default_entity, subscription_other_entity),
                current_date.to_i,
                invoicing_reason: :subscription_periodic
              )
          end
        end
      end

      context "when subscriptions share the same effective billing entity" do
        let(:subscription1) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:subscription2) do
          create(
            :subscription,
            customer:,
            plan:,
            billing_entity: customer.billing_entity,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end

        before do
          subscription1
          subscription2
        end

        it "groups them into a single billing job" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(
              contain_exactly(subscription1, subscription2),
              current_date.to_i,
              invoicing_reason: :subscription_periodic
            )
        end
      end
    end

    context "when a subscription opts out of invoice consolidation" do
      let(:interval) { :monthly }
      let(:billing_time) { :anniversary }
      let(:current_date) { subscription_at.next_month }

      let(:consolidated_subscription) do
        create(
          :subscription,
          customer:,
          plan:,
          subscription_at:,
          started_at: current_date - 10.days,
          billing_time:,
          created_at:
        )
      end
      let(:opted_out_subscription) do
        create(
          :subscription,
          customer:,
          plan:,
          subscription_at:,
          started_at: current_date - 10.days,
          billing_time:,
          created_at:,
          consolidate_invoice: false
        )
      end

      before do
        subscription.destroy
        consolidated_subscription
        opted_out_subscription
      end

      it "bills the opted-out subscription on its own and consolidates the others" do
        billing_service.call

        expect(BillSubscriptionJob).to have_been_enqueued
          .with([consolidated_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([opted_out_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
        expect(BillNonInvoiceableFeesJob).to have_been_enqueued
          .with([consolidated_subscription], current_date)
        expect(BillNonInvoiceableFeesJob).to have_been_enqueued
          .with([opted_out_subscription], current_date)
      end

      context "when several subscriptions opt out" do
        let(:other_opted_out_subscription) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            consolidate_invoice: false
          )
        end

        before { other_opted_out_subscription }

        it "produces a dedicated billing job per opted-out subscription" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([opted_out_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([other_opted_out_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([consolidated_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
        end
      end

      context "when all subscriptions opt out" do
        let(:consolidated_subscription) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            consolidate_invoice: false
          )
        end

        it "produces a one-subscription billing job per subscription with no empty groups" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with([consolidated_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([opted_out_subscription], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).not_to have_been_enqueued
            .with([], current_date.to_i, invoicing_reason: :subscription_periodic)
        end
      end

      context "when combined with currency grouping" do
        let(:organization) { create(:organization, feature_flags: ["multi_currency"]) }
        let(:usd_plan) { create(:plan, organization:, interval:, amount_currency: "USD") }
        let(:eur_plan) { create(:plan, organization:, interval:, amount_currency: "EUR") }

        let(:usd_consolidated) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:other_usd_consolidated) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:eur_consolidated) do
          create(
            :subscription,
            customer:,
            plan: eur_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:usd_opted_out) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            consolidate_invoice: false
          )
        end

        before do
          consolidated_subscription.destroy
          opted_out_subscription.destroy
          usd_consolidated
          other_usd_consolidated
          eur_consolidated
          usd_opted_out
        end

        it "keeps currency groups together while splitting the opted-out subscription out" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(contain_exactly(usd_consolidated, other_usd_consolidated), current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([eur_consolidated], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([usd_opted_out], current_date.to_i, invoicing_reason: :subscription_periodic)
        end
      end

      context "when combined with billing entity grouping" do
        let(:organization) { create(:organization, feature_flags: ["multi_entity_billing"]) }
        let(:other_billing_entity) { create(:billing_entity, organization:) }

        let(:default_entity_consolidated) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:other_default_entity_consolidated) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:other_entity_consolidated) do
          create(
            :subscription,
            customer:,
            plan:,
            billing_entity: other_billing_entity,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:
          )
        end
        let(:other_entity_opted_out) do
          create(
            :subscription,
            customer:,
            plan:,
            billing_entity: other_billing_entity,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            consolidate_invoice: false
          )
        end

        before do
          consolidated_subscription.destroy
          opted_out_subscription.destroy
          default_entity_consolidated
          other_default_entity_consolidated
          other_entity_consolidated
          other_entity_opted_out
        end

        it "keeps billing entity groups together while splitting the opted-out subscription out" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(contain_exactly(default_entity_consolidated, other_default_entity_consolidated), current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([other_entity_consolidated], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([other_entity_opted_out], current_date.to_i, invoicing_reason: :subscription_periodic)
        end
      end

      context "when combined with payment method grouping" do
        let(:organization) { create(:organization) }

        let(:provider_consolidated) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:other_provider_consolidated) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:manual_consolidated) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "manual"
          )
        end
        let(:provider_opted_out) do
          create(
            :subscription,
            customer:,
            plan:,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider",
            consolidate_invoice: false
          )
        end

        before do
          consolidated_subscription.destroy
          opted_out_subscription.destroy
          provider_consolidated
          other_provider_consolidated
          manual_consolidated
          provider_opted_out
        end

        it "keeps payment method groups together while splitting the opted-out subscription out" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(contain_exactly(provider_consolidated, other_provider_consolidated), current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([manual_consolidated], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([provider_opted_out], current_date.to_i, invoicing_reason: :subscription_periodic)
        end
      end

      context "when combined with payment method, currency and billing entity grouping" do
        let(:organization) do
          create(:organization, feature_flags: %w[multi_currency multi_entity_billing])
        end
        let(:other_billing_entity) { create(:billing_entity, organization:) }
        let(:usd_plan) { create(:plan, organization:, interval:, amount_currency: "USD") }
        let(:eur_plan) { create(:plan, organization:, interval:, amount_currency: "EUR") }

        let(:default_usd_provider) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:other_default_usd_provider) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:default_eur_provider) do
          create(
            :subscription,
            customer:,
            plan: eur_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:default_usd_manual) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "manual"
          )
        end
        let(:other_entity_usd_provider) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            billing_entity: other_billing_entity,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider"
          )
        end
        let(:default_usd_provider_opted_out) do
          create(
            :subscription,
            customer:,
            plan: usd_plan,
            subscription_at:,
            started_at: current_date - 10.days,
            billing_time:,
            created_at:,
            payment_method_type: "provider",
            consolidate_invoice: false
          )
        end

        before do
          consolidated_subscription.destroy
          opted_out_subscription.destroy
          default_usd_provider
          other_default_usd_provider
          default_eur_provider
          default_usd_manual
          other_entity_usd_provider
          default_usd_provider_opted_out
        end

        it "splits the opted-out subscription out of its (default-entity, USD, provider) group" do
          billing_service.call

          expect(BillSubscriptionJob).to have_been_enqueued
            .with(contain_exactly(default_usd_provider, other_default_usd_provider), current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([default_eur_provider], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([default_usd_manual], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([other_entity_usd_provider], current_date.to_i, invoicing_reason: :subscription_periodic)
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([default_usd_provider_opted_out], current_date.to_i, invoicing_reason: :subscription_periodic)

          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with(contain_exactly(default_usd_provider, other_default_usd_provider), current_date)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([default_eur_provider], current_date)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([default_usd_manual], current_date)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([other_entity_usd_provider], current_date)
          expect(BillNonInvoiceableFeesJob).to have_been_enqueued
            .with([default_usd_provider_opted_out], current_date)
        end
      end
    end
  end
end
