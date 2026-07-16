# frozen_string_literal: true

require "rails_helper"

describe "Billing Subscriptions Scenario" do
  let(:organization) { create(:organization, webhook_url: nil) }

  let(:timezone) { "UTC" }
  let(:customer) { create(:customer, organization:, timezone:, currency: "GBP") }

  let(:plan_monthly_charges) { false }
  let(:plan) do
    create(
      :plan,
      organization:,
      amount_cents: 5_000_000,
      amount_currency: "GBP",
      interval: plan_interval,
      pay_in_advance: false,
      bill_charges_monthly: plan_monthly_charges
    )
  end

  shared_examples "a subscription billing without duplicated invoices" do
    it "creates an invoice" do
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

      subscription = customer.subscriptions.first

      # Does not create invoices before the billing day
      before_billing_times.each do |time|
        travel_to(time) do
          expect { perform_billing }.not_to change { subscription.reload.invoices.count }
        end
      end

      # Create only one invoice on billing day
      expect do
        billing_times.each do |time|
          travel_to(time) do
            perform_billing
          end
        end
      end.to change { subscription.reload.invoices.count }.from(0).to(1)

      # Does not create invoices after the billing day
      after_billing_times.each do |time|
        travel_to(time) do
          expect { perform_billing }.not_to change { subscription.reload.invoices.count }
        end
      end
    end
  end

  shared_examples "a subscription billing on every billing day" do
    it "creates an invoice" do
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

      subscription = customer.subscriptions.first

      # Create an invoice on each billing day
      expect do
        billing_times.each do |time|
          travel_to(time) do
            perform_billing
          end
        end
      end.to change { subscription.reload.invoices.count }.from(0).to(billing_times.count)
    end
  end

  context "with weekly plan" do
    let(:plan_interval) { "weekly" }

    context "with calendar billing" do
      let(:billing_time) { "calendar" }
      let(:subscription_time) { DateTime.new(2023, 2, 1) }

      let(:before_billing_times) { [DateTime.new(2023, 2, 5)] }
      let(:billing_times) { [DateTime.new(2023, 2, 6, 1), DateTime.new(2023, 2, 6, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 2, 7, 1)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "with UTC+ timezone" do
        let(:timezone) { "Asia/Kolkata" }
        let(:subscription_time) { DateTime.new(2023, 2, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 2, 12, 18, 0) # 12th of Feb 18:00 UTC - 12th of Feb 23:30 Asia/Kolkata
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 2, 12, 19, 0), # 12th of Feb 19:00 UTC - 13th of Feb 00:30 Asia/Kolkata
            DateTime.new(2023, 2, 13, 0, 0), # 13th of Feb 00:00 UTC - 13th of Feb 05:30 Asia/Kolkata
            DateTime.new(2023, 2, 13, 18, 0) # 13th of Feb 18:00 UTC - 13th of Feb 23:30 Asia/Kolkata
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 2, 13, 19, 0)] # 13th of Feb 19:00 UTC - 14th of Feb 00:30 Asia/Kolkata
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2023, 2, 1, 6, 10) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 2, 13, 4, 0) # 13th of Feb 04:00 UTC - 12th of Feb 23:00 America/Bogota
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 2, 13, 5, 0), # 13th of Feb 05:00 UTC - 13th of Feb 00:00 America/Bogota
            DateTime.new(2023, 2, 13, 6, 0), # 13th of Feb 06:00 UTC - 13th of Feb 1:00 America/Bogota
            DateTime.new(2023, 2, 13, 3, 0), # 13th of Feb 23:00 UTC - 13th of Feb 18:00 America/Bogota
            DateTime.new(2023, 2, 14, 4, 0) # 14th of Feb 04:00 UTC - 13th of Feb 23:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 2, 14, 5, 0)] # 14th of Feb 05:00 UTC - 14th of Feb 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end

    context "with anniversary billing" do
      let(:billing_time) { "anniversary" }
      let(:subscription_time) { DateTime.new(2023, 2, 1) }

      let(:before_billing_times) { [DateTime.new(2023, 2, 14)] }
      let(:billing_times) { [DateTime.new(2023, 2, 15, 1), DateTime.new(2023, 2, 15, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 2, 16, 1)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "with UTC+ timezone" do
        let(:timezone) { "Europe/Paris" }
        let(:subscription_time) { DateTime.new(2023, 5, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 5, 22, 21, 0) # 22sd of May 21:00 UTC - 22sd of May 23:00 Europe/Paris
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 5, 22, 22, 0), # 22sd of May 22:00 UTC - 23rd of May 00:00 Europe/Paris
            DateTime.new(2023, 5, 23, 20, 0), # 23rd of May 20:00 UTC - 23rd of May 22:00 Europe/Paris
            DateTime.new(2023, 5, 23, 21, 0), # 23rd of May 21:00 UTC - 23rd of May 23:00 Europe/Paris
            DateTime.new(2023, 5, 23, 22, 10) # 23rd of May 22:59 UTC - 24th of May 00:59 Europe/Paris
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 5, 24, 0, 10)] # 24th of May 00:10 UTC - 24th of May 02:10 Europe/Paris
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2023, 2, 1, 6, 10) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 2, 15, 4, 0) # 15th of Feb 04:00 UTC - 14th of Feb 23:00 America/Bogota
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 2, 15, 5, 0), # 15th of Feb 05:00 UTC - 15th of Feb 00:00 America/Bogota
            DateTime.new(2023, 2, 15, 6, 0), # 15th of Feb 06:00 UTC - 15th of Feb 1:00 America/Bogota
            DateTime.new(2023, 2, 15, 3, 0), # 15th of Feb 23:00 UTC - 15th of Feb 18:00 America/Bogota
            DateTime.new(2023, 2, 16, 4, 0) # 16th of Feb 04:00 UTC - 15th of Feb 23:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 2, 16, 5, 0)] # 16th of Feb 05:00 UTC - 16th of Feb 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end
  end

  context "with monthly plan" do
    let(:plan_interval) { "monthly" }

    context "with calendar billing" do
      let(:billing_time) { "calendar" }
      let(:subscription_time) { DateTime.new(2023, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2023, 2, 28)] }
      let(:billing_times) { [DateTime.new(2023, 3, 1, 1), DateTime.new(2023, 3, 1, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 3, 2)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "with UTC+ timezone" do
        let(:timezone) { "Asia/Kolkata" }
        let(:subscription_time) { DateTime.new(2023, 2, 1) }

        let(:before_billing_times) do
          [DateTime.new(2023, 2, 28, 18, 0)] # 28 of Feb 18:00 UTC - 28 Feb 23:30 Asia/Kolkata
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 2, 28, 19, 0), # 28 of Feb 19:00 UTC - 1st of Mar 00:30 Asia/Kolkata
            DateTime.new(2023, 3, 1, 0, 0), # 1st of Mar 00:00 UTC - 1st of Mar 05:30 Asia/Kolkata
            DateTime.new(2023, 3, 1, 18, 0) # 1st of Mar 18:00 UTC - 1st of Mar 23:30 Asia/Kolkata
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 3, 1, 19, 0), # 1st of Mar 19:00 UTC - 2nd of Mar 00:30 Asia/Kolkata
            DateTime.new(2023, 3, 2, 0, 0) # 2nd of Mar 00:00 UTC - 2nd of Mar 05:30 Asia/Kolkata
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2023, 2, 2, 19) }

        let(:before_billing_times) do
          [DateTime.new(2023, 3, 1, 0, 0)] # 1st of Mar 00:00 UTC - 28th of Feb 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 1, 5, 0), # 1st of Mar 05:00 UTC - 1st of Mar 00:00 America/Bogota
            DateTime.new(2023, 3, 1, 6, 0), # 1st of Mar 06:00 UTC - 1st of Mar 01:00 America/Bogota
            DateTime.new(2023, 3, 1, 0, 0), # 2nd of Mar 00:00 UTC - 1st of Mar 19:00 America/Bogota
            DateTime.new(2023, 3, 2, 4, 0) # 2nd of Mar 04:00 UTC - 1st of Mar 23:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 3, 2, 5, 0), # 2nd of Mar 05:00 UTC - 2nd of Mar 00:00 America/Bogota
            DateTime.new(2023, 3, 3, 5, 0) # 3th of Mar 05:00 UTC - 3th of Mar 00:00 America/Bogota
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end

    context "with anniversary billing" do
      let(:billing_time) { "anniversary" }
      let(:subscription_time) { DateTime.new(2023, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2023, 3, 3)] }
      let(:billing_times) { [DateTime.new(2023, 3, 4, 1), DateTime.new(2023, 3, 4, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 3, 5)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "when subscription started on a 31st" do
        let(:subscription_time) { DateTime.new(2023, 3, 31) }

        let(:before_billing_times) { [DateTime.new(2023, 4, 29)] }
        let(:billing_times) { [DateTime.new(2023, 4, 30)] }
        let(:after_billing_times) { [DateTime.new(2023, 5, 1)] }

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with anniversary on a 31st" do
        let(:billing_times) do
          [
            DateTime.new(2023, 1, 31, 1),
            DateTime.new(2023, 2, 28, 1),
            DateTime.new(2023, 3, 31, 1),
            DateTime.new(2023, 4, 30, 1),
            DateTime.new(2023, 5, 31, 1),
            DateTime.new(2023, 6, 30, 1),
            DateTime.new(2023, 7, 31, 2),
            DateTime.new(2023, 8, 31, 2),
            DateTime.new(2023, 9, 30, 2),
            DateTime.new(2023, 10, 31, 2),
            DateTime.new(2023, 11, 30, 2),
            DateTime.new(2023, 12, 31, 2),
            DateTime.new(2024, 1, 31, 2),
            DateTime.new(2024, 2, 29, 2),
            DateTime.new(2024, 3, 31, 2)
          ]
        end

        let(:subscription_time) { DateTime.new(2022, 12, 31) }

        it_behaves_like "a subscription billing on every billing day"
      end

      context "with anniversary on a 30" do
        let(:billing_times) do
          [
            DateTime.new(2023, 1, 30, 1),
            DateTime.new(2023, 2, 28, 1),
            DateTime.new(2023, 3, 30, 1),
            DateTime.new(2023, 4, 30, 1),
            DateTime.new(2023, 5, 30, 1),
            DateTime.new(2023, 6, 30, 1),
            DateTime.new(2023, 7, 30, 2),
            DateTime.new(2023, 8, 30, 2),
            DateTime.new(2023, 9, 30, 2),
            DateTime.new(2023, 10, 30, 2),
            DateTime.new(2023, 11, 30, 2),
            DateTime.new(2023, 12, 30, 2),
            DateTime.new(2024, 2, 29, 2),
            DateTime.new(2024, 3, 30, 2)
          ]
        end

        let(:subscription_time) { DateTime.new(2022, 4, 30) }

        it_behaves_like "a subscription billing on every billing day"
      end

      context "with anniversary on a 28 of february" do
        let(:billing_times) do
          [
            DateTime.new(2023, 1, 28, 1),
            DateTime.new(2023, 2, 28, 1),
            DateTime.new(2023, 3, 28, 1),
            DateTime.new(2023, 4, 28, 1),
            DateTime.new(2023, 5, 28, 1),
            DateTime.new(2023, 6, 28, 1),
            DateTime.new(2023, 7, 28, 2),
            DateTime.new(2023, 8, 28, 2),
            DateTime.new(2023, 9, 28, 2),
            DateTime.new(2023, 10, 28, 2),
            DateTime.new(2023, 11, 28, 2),
            DateTime.new(2023, 12, 28, 2)
          ]
        end

        let(:subscription_time) { DateTime.new(2022, 2, 28) }

        it_behaves_like "a subscription billing on every billing day"
      end

      context "with UTC+ timezone" do
        let(:timezone) { "Asia/Kolkata" }
        let(:subscription_time) { DateTime.new(2023, 2, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 3, 1, 18, 0) # 1st of Mar 18:00 UTC - 1st of Mar 23:30 Asia/Kolkata
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 1, 19, 0), # 1st of Mar 19:00 UTC - 2nd of Mar 00:30 Asia/Kolkata
            DateTime.new(2023, 3, 2, 0, 0), # 2nd of Mar 00:00 UTC - 2nd of Mar 05:30 Asia/Kolkata
            DateTime.new(2023, 3, 2, 18, 0) # 2nd of Mar 18:00 UTC - 2nd of Mar 23:30 Asia/Kolkata
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 3, 2, 19, 0)] # 2nd of Mar 19:00 UTC - 3rd of Mar 00:30 Asia/Kolkata
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2023, 2, 2, 5) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 3, 1, 23, 0), # 1st of Mar 23:00 UTC - 1st of Mar 18:00 America/Bogota
            DateTime.new(2023, 3, 2, 4, 0) # 2nd of Mar 04:00 UTC - 1st of Mar 23:00 America/Bogota
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 2, 6, 0), # 2nd of Mar 06:00 UTC - 2nd of Mar 01:00 America/Bogota
            DateTime.new(2023, 3, 1, 7, 0), # 2nd of Mar 07:00 UTC - 2nd of Mar 02:00 America/Bogota
            DateTime.new(2023, 3, 3, 0, 0) # 3rd of Mar 00:00 UTC - 2nd of Mar 19:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 3, 3, 5, 0)] # 3rd of Mar 05:00 UTC - 3rd of Mar 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end
  end

  context "with quarterly plan" do
    let(:plan_interval) { "quarterly" }

    context "with calendar billing" do
      let(:billing_time) { "calendar" }
      let(:subscription_time) { DateTime.new(2023, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2023, 3, 1)] }
      let(:billing_times) { [DateTime.new(2023, 4, 1, 1), DateTime.new(2023, 4, 1, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 5, 1)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "with UTC+ timezone" do
        let(:timezone) { "Asia/Kolkata" }
        let(:subscription_time) { DateTime.new(2023, 2, 1) }

        let(:before_billing_times) do
          [DateTime.new(2023, 3, 31, 18, 0)] # 31 of Mar 18:00 UTC - 31 Mar 23:30 Asia/Kolkata
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 31, 19, 0), # 31 of Mar 19:00 UTC - 1st of Apr 00:30 Asia/Kolkata
            DateTime.new(2023, 4, 1, 0, 0), # 1st of Apr 00:00 UTC - 1st of Apr 05:30 Asia/Kolkata
            DateTime.new(2023, 4, 1, 18, 0) # 1st of Apr 18:00 UTC - 1st of Apr 23:30 Asia/Kolkata
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 4, 1, 19, 0), # 1st of Apr 19:00 UTC - 2nd of Apr 00:30 Asia/Kolkata
            DateTime.new(2023, 4, 2, 0, 0) # 2nd of Apr 00:00 UTC - 2nd of Apr 05:30 Asia/Kolkata
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2023, 2, 2, 19) }

        let(:before_billing_times) do
          [DateTime.new(2023, 4, 1, 0, 0)] # 1st of Apr 00:00 UTC - 31th of Mar 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 4, 1, 5, 0), # 1st of Apr 05:00 UTC - 1st of Apr 00:00 America/Bogota
            DateTime.new(2023, 4, 1, 6, 0), # 1st of Apr 06:00 UTC - 1st of Apr 01:00 America/Bogota
            DateTime.new(2023, 4, 2, 0, 0), # 2nd of Apr 00:00 UTC - 1st of Apr 19:00 America/Bogota
            DateTime.new(2023, 4, 2, 4, 0) # 2nd of Apr 04:00 UTC - 1st of Apr 23:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 4, 2, 5, 0), # 2nd of Apr 05:00 UTC - 2nd of Apr 00:00 America/Bogota
            DateTime.new(2023, 4, 3, 5, 0) # 3th of Apr 05:00 UTC - 3th of Apr 00:00 America/Bogota
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end

    context "with anniversary billing" do
      let(:billing_time) { "anniversary" }
      let(:subscription_time) { DateTime.new(2023, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2023, 3, 4)] }
      let(:billing_times) { [DateTime.new(2023, 5, 4, 1), DateTime.new(2023, 5, 4, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 5, 5)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "when subscription started on a 31st" do
        let(:subscription_time) { DateTime.new(2023, 3, 31) }

        let(:before_billing_times) { [DateTime.new(2023, 6, 29)] }
        let(:billing_times) { [DateTime.new(2023, 6, 30)] }
        let(:after_billing_times) { [DateTime.new(2023, 7, 1)] }

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with anniversary on a 31st" do
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 31, 1),
            DateTime.new(2023, 6, 30, 1),
            DateTime.new(2023, 9, 30, 2),
            DateTime.new(2023, 12, 31, 2)
          ]
        end

        let(:subscription_time) { DateTime.new(2022, 12, 31) }

        it_behaves_like "a subscription billing on every billing day"
      end

      context "with anniversary on a 30" do
        let(:billing_times) do
          [
            DateTime.new(2023, 1, 30, 1),
            DateTime.new(2023, 4, 30, 1),
            DateTime.new(2023, 7, 30, 2),
            DateTime.new(2023, 10, 30, 2)
          ]
        end

        let(:subscription_time) { DateTime.new(2022, 4, 30) }

        it_behaves_like "a subscription billing on every billing day"
      end

      context "with anniversary on a 28 of february" do
        let(:billing_times) do
          [
            DateTime.new(2023, 2, 28, 1),
            DateTime.new(2023, 5, 28, 1),
            DateTime.new(2023, 8, 28, 2),
            DateTime.new(2023, 11, 28, 2)
          ]
        end

        let(:subscription_time) { DateTime.new(2022, 2, 28) }

        it_behaves_like "a subscription billing on every billing day"
      end

      context "with UTC+ timezone" do
        let(:timezone) { "Asia/Kolkata" }
        let(:subscription_time) { DateTime.new(2023, 2, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 5, 1, 18, 0) # 1st of May 18:00 UTC - 1st of May 23:30 Asia/Kolkata
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 5, 1, 19, 0), # 1st of May 19:00 UTC - 2nd of May 00:30 Asia/Kolkata
            DateTime.new(2023, 5, 2, 0, 0), # 2nd of May 00:00 UTC - 2nd of May 05:30 Asia/Kolkata
            DateTime.new(2023, 5, 2, 18, 0) # 2nd of May 18:00 UTC - 2nd of May 23:30 Asia/Kolkata
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 5, 2, 19, 0)] # 2nd of May 19:00 UTC - 3rd of May 00:30 Asia/Kolkata
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2023, 2, 2, 5) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 5, 1, 23, 0), # 1st of May 23:00 UTC - 1st of May 18:00 America/Bogota
            DateTime.new(2023, 5, 2, 4, 0) # 2nd of May 04:00 UTC - 1st of May 23:00 America/Bogota
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 5, 2, 6, 0), # 2nd of May 06:00 UTC - 2nd of May 01:00 America/Bogota
            DateTime.new(2023, 5, 1, 7, 0), # 2nd of May 07:00 UTC - 2nd of May 02:00 America/Bogota
            DateTime.new(2023, 5, 3, 0, 0) # 3rd of May 00:00 UTC - 2nd of May 19:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 5, 3, 5, 0)] # 3rd of Mar 05:00 UTC - 3rd of Mar 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end
  end

  context "with yearly plan" do
    let(:plan_interval) { "yearly" }

    context "with calendar billing" do
      let(:billing_time) { "calendar" }
      let(:subscription_time) { DateTime.new(2022, 2, 1) }

      let(:before_billing_times) { [DateTime.new(2022, 12, 31)] }
      let(:billing_times) { [DateTime.new(2023, 1, 1, 1), DateTime.new(2023, 1, 1, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 1, 2)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "with UTC+ timezone" do
        let(:timezone) { "Europe/Paris" }
        let(:subscription_time) { DateTime.new(2022, 4, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2022, 12, 31, 21, 0) # 31th of Dec 21:00 UTC - 31th of Dec 23:00 Europe/Paris
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2022, 12, 31, 23, 0), # 31th of Dec 23:00 UTC - 1st of Jan 01:00 Europe/Paris
            DateTime.new(2023, 1, 1, 20, 0), # 1st of Jan 20:00 UTC - 1st of Jan 22:00 Europe/Paris
            DateTime.new(2023, 1, 1, 21, 0) # 1st of Jan 21:00 UTC - 1st of Jan 23:00 Europe/Paris
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 1, 1, 22, 59), # 1st of Jan 22:59 UTC - 2nd of Jan 00:59 Europe/Paris
            DateTime.new(2023, 1, 2, 0, 10) # 2nd of Jan 00:10 UTC - 2nd of Jan 02:10 Europe/Paris
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2022, 2, 4, 19) }

        let(:before_billing_times) do
          [DateTime.new(2023, 1, 1, 0, 0)] # 1st of Jan 00:00 UTC - 31th of Dec 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 1, 1, 5, 0), # 1st of Jan 05:00 UTC - 1st of Jan 00:00 America/Bogota
            DateTime.new(2023, 1, 1, 6, 0), # 1st of Jan 06:00 UTC - 1st of Jan 01:00 America/Bogota
            DateTime.new(2023, 1, 2, 0, 0) # 2nd of Jan 00:00 UTC - 1st of Jan 19:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 1, 2, 5, 0)] # 2nd of Jan 05:00 UTC - 2nd of Jan 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end

    context "with anniversary billing" do
      let(:billing_time) { "anniversary" }
      let(:subscription_time) { DateTime.new(2022, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2023, 1, 1), DateTime.new(2023, 2, 3)] }
      let(:billing_times) { [DateTime.new(2023, 2, 4, 1), DateTime.new(2023, 2, 4, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 2, 5), DateTime.new(2023, 3, 4)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "when subscription started on a 29th of February" do
        let(:subscription_time) { DateTime.new(2020, 2, 29) }

        let(:before_billing_times) { [DateTime.new(2023, 1, 28), DateTime.new(2023, 2, 27)] }
        let(:billing_times) { [DateTime.new(2023, 2, 28, 1), DateTime.new(2023, 2, 28, 2)] }
        let(:after_billing_times) { [DateTime.new(2023, 3, 1), DateTime.new(2023, 4, 29)] }

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC+ timezone" do
        let(:timezone) { "Europe/Paris" }
        let(:subscription_time) { DateTime.new(2022, 4, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 4, 1, 21, 0) # 1st of April 21:00 UTC - 1st of April 23:00 Europe/Paris
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 4, 2, 23, 0), # 1st of April 23:00 UTC - 2nd of April 01:00 Europe/Paris
            DateTime.new(2023, 4, 2, 20, 0), # 2nd of April 20:00 UTC - 2nd of April 22:00 Europe/Paris
            DateTime.new(2023, 4, 2, 21, 0), # 2nd of April 21:00 UTC - 2nd of April 23:00 Europe/Paris
            DateTime.new(2023, 4, 2, 22, 10) # 2nd of April 22:59 UTC - 3rd of April 00:59 Europe/Paris
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 4, 3, 0, 10) # 3rd of April 00:10 UTC - 3rd of April 02:10 Europe/Paris
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2022, 2, 4, 19) }

        let(:before_billing_times) do
          [DateTime.new(2023, 2, 4, 0, 0)] # 4th of Feb 00:00 UTC - 3rd Feb 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 2, 4, 5, 0), # 4th of Feb 05:00 UTC - 4th of Feb 00:00 America/Bogota
            DateTime.new(2023, 2, 4, 6, 0), # 4th of Feb 06:00 UTC - 4th of Feb 01:00 America/Bogota
            DateTime.new(2023, 2, 5, 0, 0) # 5th of Feb 00:00 UTC - 4th of Feb 19:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 2, 5, 5, 0)] # 5th of Feb 05:00 UTC - 5th of Feb 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end
  end

  context "with semiannual plan" do
    let(:plan_interval) { "semiannual" }

    context "with calendar billing" do
      let(:billing_time) { "calendar" }
      let(:subscription_time) { DateTime.new(2022, 2, 1) }

      let(:before_billing_times) { [DateTime.new(2022, 6, 30)] }
      let(:billing_times) { [DateTime.new(2022, 7, 1, 1), DateTime.new(2022, 7, 1, 2)] }
      let(:after_billing_times) { [DateTime.new(2022, 7, 2)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "with UTC+ timezone" do
        let(:timezone) { "Europe/Paris" }
        let(:subscription_time) { DateTime.new(2022, 4, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2022, 6, 30, 21, 0) # 30th of Jun 21:00 UTC - 30th of Jun 23:00 Europe/Paris
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2022, 6, 30, 23, 0), # 30th of Jun 23:00 UTC - 1st of Jul 01:00 Europe/Paris
            DateTime.new(2022, 7, 1, 20, 0), # 1st of Jul 20:00 UTC - 1st of Jul 22:00 Europe/Paris
            DateTime.new(2022, 7, 1, 21, 0) # 1st of Jul 21:00 UTC - 1st of Jul 23:00 Europe/Paris
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2022, 7, 1, 22, 59), # 1st of Jul 22:59 UTC - 2nd of Jul 00:59 Europe/Paris
            DateTime.new(2022, 7, 2, 0, 10) # 2nd of Jul 00:10 UTC - 2nd of Jul 02:10 Europe/Paris
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2022, 2, 4, 19) }

        let(:before_billing_times) do
          [DateTime.new(2022, 7, 1, 0, 0)] # 1st of Jul 00:00 UTC - 30th of Jun 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2022, 7, 1, 5, 0), # 1st of Jul 05:00 UTC - 1st of Jul 00:00 America/Bogota
            DateTime.new(2022, 7, 1, 6, 0), # 1st of Jul 06:00 UTC - 1st of Jul 01:00 America/Bogota
            DateTime.new(2022, 7, 2, 0, 0) # 2nd of Jul 00:00 UTC - 1st of Jul 19:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2022, 7, 2, 5, 0)] # 2nd of Jul 05:00 UTC - 2nd of Jul 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end

    context "with anniversary billing" do
      let(:billing_time) { "anniversary" }
      let(:subscription_time) { DateTime.new(2022, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2022, 7, 1), DateTime.new(2022, 8, 3)] }
      let(:billing_times) { [DateTime.new(2022, 8, 4, 1), DateTime.new(2022, 8, 4, 2)] }
      let(:after_billing_times) { [DateTime.new(2022, 8, 5), DateTime.new(2022, 9, 4)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "when subscription started on a 29th of February" do
        let(:subscription_time) { DateTime.new(2020, 2, 29) }

        let(:before_billing_times) { [DateTime.new(2023, 6, 28), DateTime.new(2023, 7, 27)] }
        let(:billing_times) { [DateTime.new(2023, 8, 29, 1), DateTime.new(2023, 8, 29, 2)] }
        let(:after_billing_times) { [DateTime.new(2023, 10, 1), DateTime.new(2023, 11, 29)] }

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC+ timezone" do
        let(:timezone) { "Europe/Paris" }
        let(:subscription_time) { DateTime.new(2022, 4, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2022, 9, 1, 21, 0) # 1st of September 21:00 UTC - 1st of September 23:00 Europe/Paris
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2022, 10, 1, 23, 0), # 1st of October 23:00 UTC - 2nd of October 01:00 Europe/Paris
            DateTime.new(2022, 10, 1, 20, 0), # 2nd of October 20:00 UTC - 2nd of October 22:00 Europe/Paris
            DateTime.new(2022, 10, 2, 21, 0), # 2nd of October 21:00 UTC - 2nd of October 23:00 Europe/Paris
            DateTime.new(2022, 10, 2, 22, 10) # 2nd of October 22:59 UTC - 3rd of October 00:59 Europe/Paris
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2022, 10, 3, 0, 10) # 3rd of October 00:10 UTC - 3rd of October 02:10 Europe/Paris
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2022, 2, 4, 19) }

        let(:before_billing_times) do
          [DateTime.new(2022, 2, 4, 0, 0)] # 4th of Feb 00:00 UTC - 3rd Feb 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2022, 8, 4, 5, 0), # 4th of Aug 05:00 UTC - 4th of Aug 00:00 America/Bogota
            DateTime.new(2022, 8, 4, 6, 0), # 4th of Aug 06:00 UTC - 4th of Aug 01:00 America/Bogota
            DateTime.new(2022, 8, 5, 0, 0) # 5th of Aug 00:00 UTC - 4th of Aug 19:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2022, 8, 5, 5, 0)] # 5th of Aug 05:00 UTC - 5th of Aug 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end
  end

  context "with semiannual plan and monthly charge" do
    let(:plan_interval) { "semiannual" }
    let(:plan_monthly_charges) { true }

    context "with calendar billing" do
      let(:billing_time) { "calendar" }

      let(:subscription_time) { DateTime.new(2022, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2021, 12, 31)] }
      let(:billing_times) { [DateTime.new(2022, 7, 1, 1), DateTime.new(2022, 7, 1, 2)] }
      let(:after_billing_times) { [DateTime.new(2022, 7, 2)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "with UTC+ timezone" do
        let(:timezone) { "Asia/Kolkata" }
        let(:subscription_time) { DateTime.new(2023, 2, 2) }

        let(:before_billing_times) do
          [DateTime.new(2023, 2, 28, 18, 0)] # 28 of Feb 18:00 UTC - 28 Feb 23:30 Asia/Kolkata
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 2, 28, 19, 0), # 28 of Feb 19:00 UTC - 1st of Mar 00:30 Asia/Kolkata
            DateTime.new(2023, 3, 1, 0, 0), # 1st of Mar 00:00 UTC - 1st of Mar 05:30 Asia/Kolkata
            DateTime.new(2023, 3, 1, 18, 0) # 1st of Mar 18:00 UTC - 1st of Mar 23:30 Asia/Kolkata
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 3, 1, 19, 0), # 1st of Mar 19:00 UTC - 2nd of Mar 00:30 Asia/Kolkata
            DateTime.new(2023, 3, 2, 0, 0) # 2nd of Mar 00:00 UTC - 2nd of Mar 05:30 Asia/Kolkata
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2022, 2, 2, 19) }

        let(:before_billing_times) do
          [DateTime.new(2023, 3, 1, 0, 0)] # 1st of Mar 00:00 UTC - 28th of Feb 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 1, 5, 0), # 1st of Mar 05:00 UTC - 1st of Mar 00:00 America/Bogota
            DateTime.new(2023, 3, 1, 6, 0), # 1st of Mar 06:00 UTC - 1st of Mar 01:00 America/Bogota
            DateTime.new(2023, 3, 1, 0, 0), # 2nd of Mar 00:00 UTC - 1st of Mar 19:00 America/Bogota
            DateTime.new(2023, 3, 2, 4, 0) # 2nd of Mar 04:00 UTC - 1st of Mar 23:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 3, 2, 5, 0), # 2nd of Mar 05:00 UTC - 2nd of Mar 00:00 America/Bogota
            DateTime.new(2023, 3, 3, 5, 0) # 3th of Mar 05:00 UTC - 3th of Mar 00:00 America/Bogota
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end

    context "with anniversary billing" do
      let(:billing_time) { "anniversary" }

      let(:subscription_time) { DateTime.new(2022, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2023, 1, 3)] }
      let(:billing_times) { [DateTime.new(2023, 1, 4, 1), DateTime.new(2023, 1, 4, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 1, 5)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "when subscription started on a 31st" do
        let(:subscription_time) { DateTime.new(2023, 3, 31) }

        let(:before_billing_times) { [DateTime.new(2023, 4, 29)] }
        let(:billing_times) { [DateTime.new(2023, 4, 30)] }
        let(:after_billing_times) { [DateTime.new(2023, 5, 1)] }

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC+ timezone" do
        let(:timezone) { "Europe/Paris" }
        let(:subscription_time) { DateTime.new(2022, 4, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 4, 1, 21, 0) # 1st of April 21:00 UTC - 1st of April 23:00 Europe/Paris
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 4, 2, 22, 0), # 1st of April 23:00 UTC - 2nd of April 01:00 Europe/Paris
            DateTime.new(2023, 4, 2, 20, 0), # 2nd of April 20:00 UTC - 2nd of April 22:00 Europe/Paris
            DateTime.new(2023, 4, 2, 21, 0), # 2nd of April 21:00 UTC - 2nd of April 23:00 Europe/Paris
            DateTime.new(2023, 4, 2, 22, 10) # 2nd of April 22:59 UTC - 3rd of April 00:59 Europe/Paris
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 4, 3, 0, 10) # 3rd of April 00:10 UTC - 3rd of April 02:10 Europe/Paris
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2022, 2, 4, 19) }

        let(:before_billing_times) do
          [DateTime.new(2023, 3, 4, 0, 0)] # 4th of Mar 00:00 UTC - 3rd Feb 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 4, 5, 0), # 4th of Mar 05:00 UTC - 4th of Mar 00:00 America/Bogota
            DateTime.new(2023, 3, 4, 6, 0), # 4th of Mar 06:00 UTC - 4th of Mar 01:00 America/Bogota
            DateTime.new(2023, 3, 5, 0, 0) # 5th of Mar 00:00 UTC - 4th of Mar 19:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 3, 5, 5, 0)] # 5th of Mar 05:00 UTC - 5th of Mar 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end
  end

  context "with yearly plan and monthly charge" do
    let(:plan_interval) { "yearly" }
    let(:plan_monthly_charges) { true }

    context "with calendar billing" do
      let(:billing_time) { "calendar" }

      let(:subscription_time) { DateTime.new(2022, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2021, 12, 31)] }
      let(:billing_times) { [DateTime.new(2023, 1, 1, 1), DateTime.new(2023, 1, 1, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 1, 2)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "with UTC+ timezone" do
        let(:timezone) { "Asia/Kolkata" }
        let(:subscription_time) { DateTime.new(2023, 2, 2) }

        let(:before_billing_times) do
          [DateTime.new(2023, 2, 28, 18, 0)] # 28 of Feb 18:00 UTC - 28 Feb 23:30 Asia/Kolkata
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 2, 28, 19, 0), # 28 of Feb 19:00 UTC - 1st of Mar 00:30 Asia/Kolkata
            DateTime.new(2023, 3, 1, 0, 0), # 1st of Mar 00:00 UTC - 1st of Mar 05:30 Asia/Kolkata
            DateTime.new(2023, 3, 1, 18, 0) # 1st of Mar 18:00 UTC - 1st of Mar 23:30 Asia/Kolkata
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 3, 1, 19, 0), # 1st of Mar 19:00 UTC - 2nd of Mar 00:30 Asia/Kolkata
            DateTime.new(2023, 3, 2, 0, 0) # 2nd of Mar 00:00 UTC - 2nd of Mar 05:30 Asia/Kolkata
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2022, 2, 2, 19) }

        let(:before_billing_times) do
          [DateTime.new(2023, 3, 1, 0, 0)] # 1st of Mar 00:00 UTC - 28th of Feb 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 1, 5, 0), # 1st of Mar 05:00 UTC - 1st of Mar 00:00 America/Bogota
            DateTime.new(2023, 3, 1, 6, 0), # 1st of Mar 06:00 UTC - 1st of Mar 01:00 America/Bogota
            DateTime.new(2023, 3, 1, 0, 0), # 2nd of Mar 00:00 UTC - 1st of Mar 19:00 America/Bogota
            DateTime.new(2023, 3, 2, 4, 0) # 2nd of Mar 04:00 UTC - 1st of Mar 23:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 3, 2, 5, 0), # 2nd of Mar 05:00 UTC - 2nd of Mar 00:00 America/Bogota
            DateTime.new(2023, 3, 3, 5, 0) # 3th of Mar 05:00 UTC - 3th of Mar 00:00 America/Bogota
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end

    context "with anniversary billing" do
      let(:billing_time) { "anniversary" }

      let(:subscription_time) { DateTime.new(2022, 2, 4) }

      let(:before_billing_times) { [DateTime.new(2023, 1, 3)] }
      let(:billing_times) { [DateTime.new(2023, 1, 4, 1), DateTime.new(2023, 1, 4, 2)] }
      let(:after_billing_times) { [DateTime.new(2023, 1, 5)] }

      it_behaves_like "a subscription billing without duplicated invoices"

      context "when subscription started on a 31st" do
        let(:subscription_time) { DateTime.new(2023, 3, 31) }

        let(:before_billing_times) { [DateTime.new(2023, 4, 29)] }
        let(:billing_times) { [DateTime.new(2023, 4, 30)] }
        let(:after_billing_times) { [DateTime.new(2023, 5, 1)] }

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC+ timezone" do
        let(:timezone) { "Europe/Paris" }
        let(:subscription_time) { DateTime.new(2022, 4, 2) }

        let(:before_billing_times) do
          [
            DateTime.new(2023, 4, 1, 21, 0) # 1st of April 21:00 UTC - 1st of April 23:00 Europe/Paris
          ]
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 4, 2, 22, 0), # 1st of April 23:00 UTC - 2nd of April 01:00 Europe/Paris
            DateTime.new(2023, 4, 2, 20, 0), # 2nd of April 20:00 UTC - 2nd of April 22:00 Europe/Paris
            DateTime.new(2023, 4, 2, 21, 0), # 2nd of April 21:00 UTC - 2nd of April 23:00 Europe/Paris
            DateTime.new(2023, 4, 2, 22, 10) # 2nd of April 22:59 UTC - 3rd of April 00:59 Europe/Paris
          ]
        end
        let(:after_billing_times) do
          [
            DateTime.new(2023, 4, 3, 0, 10) # 3rd of April 00:10 UTC - 3rd of April 02:10 Europe/Paris
          ]
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end

      context "with UTC- timezone" do
        let(:timezone) { "America/Bogota" }
        let(:subscription_time) { DateTime.new(2022, 2, 4, 19) }

        let(:before_billing_times) do
          [DateTime.new(2023, 3, 4, 0, 0)] # 4th of Mar 00:00 UTC - 3rd Feb 19:00 America/Bogota
        end
        let(:billing_times) do
          [
            DateTime.new(2023, 3, 4, 5, 0), # 4th of Mar 05:00 UTC - 4th of Mar 00:00 America/Bogota
            DateTime.new(2023, 3, 4, 6, 0), # 4th of Mar 06:00 UTC - 4th of Mar 01:00 America/Bogota
            DateTime.new(2023, 3, 5, 0, 0) # 5th of Mar 00:00 UTC - 4th of Mar 19:00 America/Bogota
          ]
        end
        let(:after_billing_times) do
          [DateTime.new(2023, 3, 5, 5, 0)] # 5th of Mar 05:00 UTC - 5th of Mar 00:00 America/Bogota
        end

        it_behaves_like "a subscription billing without duplicated invoices"
      end
    end
  end
end
