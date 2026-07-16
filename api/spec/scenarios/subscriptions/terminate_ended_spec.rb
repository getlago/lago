# frozen_string_literal: true

require "rails_helper"

describe "Subscriptions Termination Scenario" do
  let(:organization) { create(:organization, webhook_url: nil, email_settings: "") }

  let(:timezone) { "Europe/Paris" }
  let(:customer) { create(:customer, organization:, timezone:) }

  let(:plan) do
    create(
      :plan,
      organization:,
      interval: "monthly",
      amount_cents: 1000,
      pay_in_advance: false
    )
  end

  let(:creation_time) { Time.zone.parse("2023-09-05T00:00:00") }
  let(:subscription_at) { Time.zone.parse("2023-09-05T00:00:00") }
  let(:ending_at) { Time.zone.parse("2023-09-06T00:00:00") }

  context "when timezone is Europe/Paris" do
    it "terminates the subscription when it reaches its ending date" do
      subscription = nil

      travel_to(creation_time) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601,
            ending_at: ending_at.iso8601
          }
        )

        subscription = customer.subscriptions.first
        expect(subscription).to be_active
      end

      travel_to(ending_at + 15.minutes) do
        Clock::TerminateEndedSubscriptionsJob.perform_now

        perform_all_enqueued_jobs

        invoice = subscription.invoices.first

        expect(subscription.reload).to be_terminated
        expect(subscription.reload.invoices.count).to eq(1)
        expect(invoice.total_amount_cents).to eq(67) # 1000 / 30
        expect(invoice.issuing_date.iso8601).to eq("2023-09-06")
      end
    end
  end

  context "when timezone is Asia/Bangkok" do
    let(:timezone) { "Asia/Bangkok" }
    let(:creation_time) { DateTime.new(2023, 9, 5, 0, 0) }
    let(:subscription_at) { DateTime.new(2023, 9, 5, 0, 0) }
    let(:ending_at) { DateTime.new(2023, 9, 6, 0, 0) }

    it "terminates the subscription when it reaches its ending date" do
      subscription = nil

      travel_to(creation_time) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601,
            ending_at: ending_at.iso8601
          }
        )

        subscription = customer.subscriptions.first
        expect(subscription).to be_active
      end

      travel_to(ending_at + 15.minutes) do
        Clock::TerminateEndedSubscriptionsJob.perform_now

        perform_all_enqueued_jobs

        invoice = subscription.invoices.first

        expect(subscription.reload).to be_terminated
        expect(subscription.reload.invoices.count).to eq(1)
        expect(invoice.total_amount_cents).to eq(67) # 1000 / 30
        expect(invoice.issuing_date.iso8601).to eq("2023-09-06")
      end
    end
  end

  context "when timezone is America/Bogota" do
    let(:timezone) { "America/Bogota" }

    it "terminates the subscription when it reaches its ending date" do
      subscription = nil

      travel_to(creation_time) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601,
            ending_at: ending_at.iso8601
          }
        )

        subscription = customer.subscriptions.first
        expect(subscription).to be_active
      end

      travel_to(ending_at + 15.minutes) do
        Clock::TerminateEndedSubscriptionsJob.perform_now

        perform_all_enqueued_jobs

        invoice = subscription.invoices.first

        expect(subscription.reload).to be_terminated
        expect(subscription.reload.invoices.count).to eq(1)
        expect(invoice.total_amount_cents).to eq(67) # 1000 / 30
        expect(invoice.issuing_date.iso8601).to eq("2023-09-05")
      end
    end
  end

  context "when ending at is the same as billing date" do
    let(:ending_at) { DateTime.new(2023, 10, 5, 0, 0) }

    it "bills correctly previous billing period if it has not been billed yet" do
      subscription = nil

      travel_to(creation_time) do
        create_subscription(
          {
            external_customer_id: customer.external_id,
            external_id: customer.external_id,
            plan_code: plan.code,
            billing_time: "anniversary",
            subscription_at: subscription_at.iso8601,
            ending_at: ending_at.iso8601
          }
        )

        subscription = customer.subscriptions.first
        expect(subscription).to be_active
      end

      travel_to(ending_at + 15.minutes) do
        Clock::TerminateEndedSubscriptionsJob.perform_now

        perform_all_enqueued_jobs

        invoice = subscription.invoices.first

        expect(subscription.reload).to be_terminated
        expect(subscription.reload.invoices.count).to eq(1)
        expect(invoice.total_amount_cents).to eq(1000)
        expect(invoice.issuing_date.iso8601).to eq("2023-10-05")
      end
    end

    context "when plan is pay in advance" do
      let(:plan) do
        create(
          :plan,
          organization:,
          interval: "monthly",
          amount_cents: 1000,
          pay_in_advance: true
        )
      end

      it "does not issue credit note and does not bill previous period" do
        subscription = nil

        travel_to(creation_time) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "anniversary",
              subscription_at: subscription_at.iso8601,
              ending_at: ending_at.iso8601
            }
          )

          subscription = customer.subscriptions.first
          expect(subscription).to be_active
        end

        travel_to(ending_at + 15.minutes) do
          Clock::TerminateEndedSubscriptionsJob.perform_now

          perform_all_enqueued_jobs

          invoice = subscription.invoices.order(created_at: :desc).first

          expect(subscription.reload).to be_terminated
          expect(subscription.reload.invoices.count).to eq(2)
          expect(customer.credit_notes.count).to eq(0)
          expect(invoice.total_amount_cents).to eq(0)
          expect(invoice.issuing_date.iso8601).to eq("2023-10-05")
        end
      end
    end

    context "when ending_at is not set and subscription is terminated on the day of creation" do
      it "bills correctly only 1 day" do
        subscription = nil

        travel_to(creation_time) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "anniversary",
              subscription_at: subscription_at.iso8601,
              ending_at: nil
            }
          )

          subscription = customer.subscriptions.first
          expect(subscription).to be_active
        end

        Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
        WebhookEndpoint.destroy_all

        travel_to(creation_time + 5.hours) do
          Subscriptions::TerminateService.call(subscription:)

          perform_all_enqueued_jobs

          invoice = subscription.invoices.order(created_at: :desc).first

          expect(subscription.reload).to be_terminated
          expect(subscription.reload.invoices.count).to eq(1)
          expect(invoice.total_amount_cents).to eq(33)
          expect(invoice.issuing_date.iso8601).to eq("2023-09-05")
        end
      end
    end

    context "with America/Bogota timezone" do
      let(:timezone) { "America/Bogota" }

      it "bills correctly previous billing period if it has not been billed yet" do
        subscription = nil

        travel_to(creation_time) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "anniversary",
              subscription_at: subscription_at.iso8601,
              ending_at: ending_at.iso8601
            }
          )

          subscription = customer.subscriptions.first
          expect(subscription).to be_active
        end

        travel_to(ending_at - 5.hours) do
          Clock::TerminateEndedSubscriptionsJob.perform_now

          perform_all_enqueued_jobs

          invoice = subscription.invoices.first

          expect(subscription.reload).to be_terminated
          expect(subscription.reload.invoices.count).to eq(1)
          expect(invoice.total_amount_cents).to eq(1000)
          expect(invoice.issuing_date.iso8601).to eq("2023-10-04")
        end
      end
    end

    context "with Asia/Bangkok timezone" do
      let(:timezone) { "Asia/Bangkok" }

      it "bills correctly previous billing period if it has not been billed yet" do
        subscription = nil

        travel_to(creation_time) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "anniversary",
              subscription_at: subscription_at.iso8601,
              ending_at: ending_at.iso8601
            }
          )

          subscription = customer.subscriptions.first
          expect(subscription).to be_active
        end

        travel_to(ending_at - 5.hours) do
          Clock::TerminateEndedSubscriptionsJob.perform_now

          perform_all_enqueued_jobs

          invoice = subscription.invoices.first

          expect(subscription.reload).to be_terminated
          expect(subscription.reload.invoices.count).to eq(1)
          expect(invoice.total_amount_cents).to eq(1000)
          expect(invoice.issuing_date.iso8601).to eq("2023-10-05")
        end
      end
    end

    context "when billing time is calendar" do
      let(:creation_time) { DateTime.new(2023, 8, 1, 0, 0) }
      let(:subscription_at) { DateTime.new(2023, 8, 1, 0, 0) }
      let(:ending_at) { DateTime.new(2023, 10, 1, 0, 0) }

      it "bills correctly previous billing period if it has not been billed yet" do
        subscription = nil

        travel_to(creation_time) do
          create_subscription(
            {
              external_customer_id: customer.external_id,
              external_id: customer.external_id,
              plan_code: plan.code,
              billing_time: "calendar",
              subscription_at: subscription_at.iso8601,
              ending_at: ending_at.iso8601
            }
          )

          subscription = customer.subscriptions.first
          expect(subscription).to be_active
        end

        travel_to(ending_at + 15.minutes) do
          Clock::TerminateEndedSubscriptionsJob.perform_now

          perform_all_enqueued_jobs

          invoice = subscription.invoices.first

          expect(subscription.reload).to be_terminated
          expect(subscription.reload.invoices.count).to eq(1)
          expect(invoice.total_amount_cents).to eq(1000)
          expect(invoice.issuing_date.iso8601).to eq("2023-10-01")
        end
      end

      context "when plan is pay in advance" do
        let(:plan) do
          create(
            :plan,
            organization:,
            interval: "monthly",
            amount_cents: 1000,
            pay_in_advance: true
          )
        end

        it "does not issue credit note and does not bill previous period" do
          subscription = nil

          travel_to(creation_time) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "calendar",
                subscription_at: subscription_at.iso8601,
                ending_at: ending_at.iso8601
              }
            )

            subscription = customer.subscriptions.first
            expect(subscription).to be_active
          end

          travel_to(DateTime.new(2023, 9, 1, 0, 0)) do
            perform_billing
          end

          travel_to(ending_at + 15.minutes) do
            Clock::TerminateEndedSubscriptionsJob.perform_now

            perform_all_enqueued_jobs

            invoice = subscription.invoices.order(created_at: :desc).first

            expect(subscription.reload).to be_terminated
            expect(subscription.reload.invoices.count).to eq(3)
            expect(customer.credit_notes.count).to eq(0)
            expect(invoice.total_amount_cents).to eq(0)
            expect(invoice.issuing_date.iso8601).to eq("2023-10-01")
          end
        end
      end

      context "with already triggered subscription job" do
        it "bills correctly the previous period since billing job is not performed on ending day" do
          subscription = nil

          travel_to(creation_time) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "calendar",
                subscription_at: subscription_at.iso8601,
                ending_at: ending_at.iso8601
              }
            )

            subscription = customer.subscriptions.first
            expect(subscription).to be_active
          end

          Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
          WebhookEndpoint.destroy_all

          travel_to(ending_at + 5.minutes) do
            perform_billing

            expect(subscription.reload).to be_active
            expect(subscription.reload.invoices.count).to eq(0)
          end

          travel_to(ending_at + 15.minutes) do
            Clock::TerminateEndedSubscriptionsJob.perform_now

            perform_all_enqueued_jobs

            invoice = subscription.invoices.order(created_at: :desc).first

            expect(subscription.reload).to be_terminated
            expect(subscription.reload.invoices.count).to eq(1)
            expect(invoice.total_amount_cents).to eq(1000)
            expect(invoice.issuing_date.iso8601).to eq("2023-10-01")
          end
        end
      end

      context "with already triggered subscription job and if ending_at is not set" do
        it "bills correctly only one day for manual termination case" do
          subscription = nil

          travel_to(creation_time) do
            create_subscription(
              {
                external_customer_id: customer.external_id,
                external_id: customer.external_id,
                plan_code: plan.code,
                billing_time: "calendar",
                subscription_at: subscription_at.iso8601,
                ending_at: nil
              }
            )

            subscription = customer.subscriptions.first
            expect(subscription).to be_active
          end

          Organization.update_all(webhook_url: nil) # rubocop:disable Rails/SkipsModelValidations
          WebhookEndpoint.destroy_all

          travel_to(ending_at + 5.minutes) do
            perform_billing

            invoice = subscription.invoices.order(created_at: :desc).first

            expect(subscription.reload).to be_active
            expect(subscription.reload.invoices.count).to eq(1)
            expect(invoice.total_amount_cents).to eq(1000)
            expect(invoice.issuing_date.iso8601).to eq("2023-10-01")
          end

          travel_to(ending_at + 15.minutes) do
            Subscriptions::TerminateService.call(subscription:)

            perform_all_enqueued_jobs

            invoice = subscription.invoices.order(created_at: :desc).first

            expect(subscription.reload).to be_terminated
            expect(subscription.reload.invoices.count).to eq(2)
            expect(invoice.total_amount_cents).to eq(32)
            expect(invoice.issuing_date.iso8601).to eq("2023-10-01")
          end
        end
      end
    end
  end
end
