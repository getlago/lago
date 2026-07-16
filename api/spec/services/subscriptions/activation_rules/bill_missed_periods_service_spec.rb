# frozen_string_literal: true

require "rails_helper"

describe Subscriptions::ActivationRules::BillMissedPeriodsService do
  subject(:result) { described_class.call(subscription:) }

  let(:organization) { create(:organization) }
  let(:customer) { create(:customer, organization:) }
  let(:plan) { create(:plan, organization:, interval: :monthly, pay_in_advance: true) }
  let(:started_at) { Time.zone.parse("2026-03-05 10:00:00") }
  let(:current_time) { Time.zone.parse("2026-04-10 12:00:00") }
  let(:subscription) do
    create(:subscription, :calendar, :with_activation_rules, organization:, customer:, plan:, started_at:)
  end

  around { |test| travel_to(current_time) { test.run } }

  describe "#call" do
    context "when the subscription is not active" do
      let(:subscription) do
        create(:subscription, :incomplete, :calendar, :with_activation_rules, organization:, customer:, plan:, started_at:)
      end

      it "does not enqueue any BillSubscriptionJob" do
        expect(result).to be_success
        expect(BillSubscriptionJob).not_to have_been_enqueued
      end
    end

    context "when the subscription has a previous subscription" do
      let(:subscription) do
        create(:subscription, :calendar, :with_activation_rules, :with_previous_subscription, organization:, customer:, plan:, started_at:)
      end

      it "does not enqueue any BillSubscriptionJob" do
        expect(result).to be_success
        expect(BillSubscriptionJob).not_to have_been_enqueued
      end
    end

    context "when the subscription has no payment activation rules" do
      let(:subscription) { create(:subscription, :calendar, organization:, customer:, plan:, started_at:) }

      it "does not enqueue any BillSubscriptionJob" do
        expect(result).to be_success
        expect(BillSubscriptionJob).not_to have_been_enqueued
      end
    end

    context "when activation happens within the first period" do
      let(:current_time) { Time.zone.parse("2026-03-20 12:00:00") }

      it "does not enqueue any BillSubscriptionJob" do
        expect(result).to be_success
        expect(BillSubscriptionJob).not_to have_been_enqueued
      end
    end

    context "when one period boundary was crossed" do
      it "enqueues a BillSubscriptionJob for the missed boundary" do
        expect(result).to be_success
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-04-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
      end
    end

    context "when activation happens early on the boundary day" do
      let(:current_time) { Time.zone.parse("2026-04-01 08:00:00") }

      it "enqueues a BillSubscriptionJob for that day's tick" do
        expect(result).to be_success
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-04-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
      end
    end

    context "when several period boundaries were crossed" do
      let(:current_time) { Time.zone.parse("2026-05-10 12:00:00") }

      it "enqueues one BillSubscriptionJob per missed boundary" do
        expect(result).to be_success
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-04-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-05-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
      end
    end

    context "when a missed period was already billed" do
      before do
        dates = Subscriptions::DatesService.new_instance(subscription, Time.zone.parse("2026-04-01 00:00:01"), current_usage: false)
        invoice = create(:invoice, organization:, customer:)
        create(
          :invoice_subscription,
          subscription:,
          invoice:,
          recurring: true,
          invoicing_reason: :subscription_periodic,
          from_datetime: dates.from_datetime,
          to_datetime: dates.to_datetime
        )
      end

      it "does not enqueue a BillSubscriptionJob for that period" do
        expect(result).to be_success
        expect(BillSubscriptionJob).not_to have_been_enqueued
      end
    end

    context "when the plan is semiannual" do
      let(:plan) { create(:plan, organization:, interval: :semiannual, pay_in_advance: true) }
      let(:current_time) { Time.zone.parse("2026-07-10 12:00:00") }

      it "enqueues a BillSubscriptionJob for the missed semiannual boundary" do
        expect(result).to be_success
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-07-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
      end
    end

    context "when the plan is yearly with monthly billed charges" do
      let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: true, bill_charges_monthly: true) }
      let(:current_time) { Time.zone.parse("2026-05-10 12:00:00") }

      it "enqueues one BillSubscriptionJob per missed monthly split boundary" do
        expect(result).to be_success
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-04-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-05-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
      end

      context "when fixed charges are also billed monthly" do
        let(:plan) do
          create(:plan, organization:, interval: :yearly, pay_in_advance: true, bill_charges_monthly: true, bill_fixed_charges_monthly: true)
        end

        it "enqueues one BillSubscriptionJob per missed monthly split boundary" do
          expect(result).to be_success
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], Time.zone.parse("2026-04-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
            .once
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], Time.zone.parse("2026-05-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
            .once
        end
      end

      context "when the missed periods cross the year-end boundary" do
        let(:started_at) { Time.zone.parse("2026-11-05 10:00:00") }
        let(:current_time) { Time.zone.parse("2027-01-10 12:00:00") }

        it "enqueues one BillSubscriptionJob per missed monthly split boundary" do
          expect(result).to be_success
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], Time.zone.parse("2026-12-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
            .once
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], Time.zone.parse("2027-01-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
            .once
        end
      end
    end

    context "when the plan is yearly with monthly billed fixed charges" do
      let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: true, bill_fixed_charges_monthly: true) }
      let(:current_time) { Time.zone.parse("2026-05-10 12:00:00") }

      it "enqueues one BillSubscriptionJob per missed monthly split boundary" do
        expect(result).to be_success
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-04-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-05-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
      end

      context "when the missed periods cross the year-end boundary" do
        let(:started_at) { Time.zone.parse("2026-11-05 10:00:00") }
        let(:current_time) { Time.zone.parse("2027-01-10 12:00:00") }

        it "enqueues one BillSubscriptionJob per missed monthly split boundary" do
          expect(result).to be_success
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], Time.zone.parse("2026-12-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
            .once
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], Time.zone.parse("2027-01-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
            .once
        end
      end
    end

    context "when the plan is semiannual with monthly billed charges" do
      let(:plan) { create(:plan, organization:, interval: :semiannual, pay_in_advance: true, bill_charges_monthly: true) }
      let(:started_at) { Time.zone.parse("2026-05-05 10:00:00") }
      let(:current_time) { Time.zone.parse("2026-07-10 12:00:00") }

      it "enqueues one BillSubscriptionJob per missed monthly split boundary" do
        expect(result).to be_success
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-06-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2026-07-01 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
      end
    end

    context "when the subscription is billed on its anniversary" do
      let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: true) }
      let(:subscription) do
        create(:subscription, :anniversary, :with_activation_rules, organization:, customer:, plan:, started_at:, subscription_at: started_at)
      end
      let(:started_at) { Time.zone.parse("2026-11-10 10:00:00") }
      let(:current_time) { Time.zone.parse("2027-11-15 12:00:00") }

      it "enqueues a BillSubscriptionJob for the anniversary boundary" do
        expect(result).to be_success
        expect(BillSubscriptionJob).to have_been_enqueued
          .with([subscription], Time.zone.parse("2027-11-10 00:00:00").to_i, invoicing_reason: :subscription_periodic)
          .once
      end

      context "when charges are billed monthly" do
        let(:plan) { create(:plan, organization:, interval: :yearly, pay_in_advance: true, bill_charges_monthly: true) }
        let(:current_time) { Time.zone.parse("2027-01-15 12:00:00") }

        it "enqueues one BillSubscriptionJob per missed anniversary split boundary" do
          expect(result).to be_success
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], Time.zone.parse("2026-12-10 00:00:00").to_i, invoicing_reason: :subscription_periodic)
            .once
          expect(BillSubscriptionJob).to have_been_enqueued
            .with([subscription], Time.zone.parse("2027-01-10 00:00:00").to_i, invoicing_reason: :subscription_periodic)
            .once
        end
      end
    end
  end
end
