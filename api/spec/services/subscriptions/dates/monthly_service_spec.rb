# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::Dates::MonthlyService do
  subject(:date_service) { described_class.new(subscription, billing_at, false) }

  let(:subscription) do
    create(
      :subscription,
      plan:,
      customer:,
      subscription_at:,
      billing_time:,
      started_at:,
      previous_subscription:
    )
  end

  let(:billing_entity) { create(:billing_entity) }
  let(:customer) { create(:customer, timezone:, billing_entity:) }
  let(:plan) { create(:plan, interval: :monthly, pay_in_advance:) }
  let(:pay_in_advance) { false }

  let(:subscription_at) { Time.zone.parse("02 Feb 2021") }
  let(:billing_at) { Time.zone.parse("07 Mar 2022") }
  let(:started_at) { subscription_at }
  let(:timezone) { "UTC" }

  let(:previous_subscription) { nil }

  describe "#from_datetime" do
    let(:result) { date_service.from_datetime.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Mar 2022") }

      it "returns the beginning of the previous month" do
        expect(result).to eq("2022-02-01 00:00:00 UTC")
      end

      context "when subscription is not yet started" do
        let(:started_at) { nil }

        it "returns nil" do
          expect(date_service.from_datetime).to be_nil
        end
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-01-01 05:00:00 UTC")
        end
      end

      context "when date is before the start date" do
        let(:started_at) { Time.zone.parse("07 Feb 2022 05:00:00") }

        it "returns the start date" do
          expect(result).to eq(started_at.beginning_of_day.utc.to_s)
        end

        context "with customer timezone" do
          let(:timezone) { "America/New_York" }

          it "returns the start date" do
            expect(result).to eq(started_at.utc.to_s)
          end
        end
      end

      context "when subscription is just terminated" do
        let(:billing_at) { Time.zone.parse("10 Mar 2022") }

        before { subscription.mark_as_terminated!("9 Mar 2022") }

        it "returns the beginning of the month" do
          expect(result).to eq("2022-03-01 00:00:00 UTC")
        end

        context "when plan is pay in advance" do
          let(:pay_in_advance) { true }

          it "returns the beginning of the month" do
            expect(result).to eq("2022-03-01 00:00:00 UTC")
          end
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 Mar 2022") }

      it "returns the day in the previous month day" do
        expect(result).to eq("2022-02-02 00:00:00 UTC")
      end

      context "when date is before the start date" do
        let(:started_at) { Time.zone.parse("08 Feb 2022") }

        it "returns the start date" do
          expect(result).to eq(started_at.utc.to_s)
        end
      end

      context "when subscription is just terminated" do
        let(:billing_at) { Time.zone.parse("10 Mar 2022") }

        before { subscription.mark_as_terminated!("9 Mar 2022") }

        it "returns the previous month day" do
          expect(result).to eq("2022-03-02 00:00:00 UTC")
        end

        context "when plan is pay in advance" do
          let(:pay_in_advance) { true }

          it "returns the day in the current month" do
            expect(result).to eq("2022-03-02 00:00:00 UTC")
          end
        end

        context "when billing day after last day of billing month" do
          let(:billing_at) { Time.zone.parse("29 Mar 2022") }
          let(:subscription_at) { Time.zone.parse("31 Mar 2021") }

          it "returns the previous month last day" do
            expect(result).to eq("2022-02-28 00:00:00 UTC")
          end
        end

        context "when billing day on first month of the year" do
          before { subscription.mark_as_terminated!("27 Jan 2022") }

          let(:billing_at) { Time.zone.parse("28 Jan 2022") }
          let(:subscription_at) { Time.zone.parse("27 Mar 2021") }

          it "returns the previous month last day" do
            expect(result).to eq("2021-12-27 00:00:00 UTC")
          end
        end
      end

      context "when plan is in advance and date is on the last day of month" do
        let(:pay_in_advance) { true }

        let(:billing_at) { Time.zone.parse("30 apr 2021") }
        let(:subscription_at) { Time.zone.parse("31 mar 2021") }

        it "returns the current day" do
          expect(result).to eq("2021-04-30 00:00:00 UTC")
        end

        context "when billing month is longer than subscription one" do
          let(:billing_at) { Time.zone.parse("29 feb 2020") }
          let(:subscription_at) { Time.zone.parse("31 jan 2020") }

          it "returns the durrent day" do
            expect(result).to eq("2020-02-29 00:00:00 UTC")
          end
        end
      end

      context "when plan is in arrear and date is on the last day of month" do
        let(:billing_at) { Time.zone.parse("30 apr 2021") }
        let(:subscription_at) { Time.zone.parse("31 mar 2021") }

        it "returns the day current billing day" do
          expect(result).to eq("2021-03-31 00:00:00 UTC")
        end

        context "when subscription month is shorter than billing one" do
          let(:billing_at) { Time.zone.parse("30 mar 2020") }
          let(:subscription_at) { Time.zone.parse("30 apr 2019") }

          it "returns the current billing day" do
            expect(result).to eq("2020-02-29 00:00:00 UTC")
          end
        end
      end
    end
  end

  describe "#to_datetime" do
    let(:result) { date_service.to_datetime.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Mar 2022") }

      it "returns the end of the previous month" do
        expect(result).to eq("2022-02-28 23:59:59 UTC")
      end

      context "when subscription is not yet started" do
        let(:started_at) { nil }

        it "returns nil" do
          expect(date_service.to_datetime).to be_nil
        end
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-02-01 04:59:59 UTC")
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        it "returns the end of the month" do
          expect(result).to eq("2022-03-31 23:59:59 UTC")
        end
      end

      context "when subscription is just terminated" do
        let(:billing_at) { Time.zone.parse("10 Mar 2022") }
        let(:terminated_at) { Time.zone.parse("09 Mar 2022") }

        before { subscription.update!(status: :terminated, terminated_at:) }

        it "returns the termination date" do
          expect(result).to match_datetime(subscription.terminated_at.utc)
        end

        context "with pending next subscription" do
          let(:subscription_at) { Time.zone.parse("2024-09-09T14:00:01") }
          let(:terminated_at) { Time.zone.parse("2024-09-09T16:00:01") }

          let(:downgraded_plan) { create(:plan, interval: :monthly, pay_in_advance: false, amount_cents: 0) }

          before do
            create(
              :subscription,
              status: :pending,
              external_id: subscription.external_id,
              plan: downgraded_plan,
              customer:,
              subscription_at:,
              billing_time:,
              started_at: nil,
              previous_subscription: subscription
            )
          end

          it "makes sure the to_datetime is not before start date" do
            expect(result).to match_datetime(subscription.started_at.utc)
          end
        end

        context "with customer timezone" do
          let(:timezone) { "America/New_York" }

          it "returns the termination date" do
            expect(result).to match_datetime(subscription.terminated_at.utc)
          end
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 Mar 2022") }

      it "returns the day in the previous month" do
        expect(result).to eq("2022-03-01 23:59:59 UTC")
      end

      context "when billing last month of year" do
        let(:billing_at) { Time.zone.parse("04 Jan 2022") }

        it "returns the day in the previous month" do
          expect(result).to eq("2022-01-01 23:59:59 UTC")
        end
      end

      context "when billing subscription day does not exist in the month" do
        let(:subscription_at) { Time.zone.parse("31 Jan 2022") }
        let(:billing_at) { Time.zone.parse("28 Feb 2022") }

        it "returns the last day of the month" do
          expect(result).to eq("2022-02-27 23:59:59 UTC")
        end

        context "when subscription is not the last day of the month" do
          let(:subscription_at) { Time.zone.parse("30 Jan 2022") }

          it "returns the last day of the month" do
            expect(result).to eq("2022-02-27 23:59:59 UTC")
          end
        end
      end

      context "when anniversary date is first day of the month" do
        let(:subscription_at) { Time.zone.parse("01 Jan 2022") }
        let(:billing_at) { Time.zone.parse("02 Mar 2022") }

        it "returns the last day of the month" do
          expect(result).to eq("2022-02-28 23:59:59 UTC")
        end
      end

      context "when plan is pay in advance" do
        before { plan.update!(pay_in_advance: true) }

        it "returns the end of the current period" do
          expect(result).to eq("2022-04-01 23:59:59 UTC")
        end
      end

      context "when subscription is just terminated" do
        let(:billing_at) { Time.zone.parse("10 Mar 2022") }

        before do
          subscription.update!(
            status: :terminated,
            terminated_at: Time.zone.parse("02 Mar 2022")
          )
        end

        it "returns the termination date" do
          expect(result).to match_datetime(subscription.terminated_at.utc)
        end
      end
    end
  end

  describe "#charges_from_datetime" do
    let(:result) { date_service.charges_from_datetime.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Mar 2022") }

      it "returns from_datetime" do
        expect(result).to eq(date_service.from_datetime.to_s)
      end

      context "when subscription is not yet started" do
        let(:started_at) { nil }

        it "returns nil" do
          expect(date_service.charges_from_datetime).to be_nil
        end
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq(date_service.from_datetime.to_s)
        end

        context "when timezone has changed" do
          let(:billing_at) { Time.zone.parse("02 Mar 2022") }

          let(:previous_invoice_subscription) do
            create(
              :invoice_subscription,
              subscription:,
              charges_to_datetime: "2022-01-31T23:59:59Z"
            )
          end

          before do
            previous_invoice_subscription
            subscription.customer.update!(timezone: "America/Los_Angeles")
          end

          it "takes previous invoice into account" do
            expect(result).to match_datetime("2022-02-01 00:00:00")
          end
        end

        context "when timezone has changed and there are no invoices generated in the past" do
          let(:billing_at) { Time.zone.parse("02 Mar 2022") }

          before do
            subscription.customer.update!(timezone: "America/Los_Angeles")
          end

          it "takes calculates correct datetime" do
            expect(result).to eq(date_service.from_datetime.to_s)
          end
        end
      end

      context "when subscription started in the middle of a period" do
        let(:started_at) { Time.zone.parse("03 Mar 2022") }

        it "returns the start date" do
          expect(result).to eq(subscription.started_at.utc.to_s)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }
        let(:subscription_at) { Time.zone.parse("02 Feb 2020") }

        it "returns the start of the previous period" do
          expect(result).to eq("2022-02-01 00:00:00 UTC")
        end
      end

      context "when previous subscription is upgraded" do
        let(:started_at) { Time.zone.parse("2024-02-22T16:13:00") }

        let(:previous_subscription) do
          create(
            :subscription,
            :terminated,
            terminated_at: started_at
          )
        end

        it "returns the beginning of the start date" do
          expect(result).to eq(subscription.started_at.utc.to_s) # boundary should be terminated_at
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 Mar 2022") }

      it "returns from_datetime" do
        expect(result).to eq(date_service.from_datetime.to_s)
      end

      context "when subscription started in the middle of a period" do
        let(:started_at) { Time.zone.parse("03 Mar 2022") }

        it "returns the start date" do
          expect(result).to eq(subscription.started_at.utc.to_s)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }
        let(:subscription_at) { Time.zone.parse("02 Feb 2020") }

        it "returns the start of the previous period" do
          expect(result).to eq("2022-02-02 00:00:00 UTC")
        end
      end
    end
  end

  describe "#charges_to_datetime" do
    let(:result) { date_service.charges_to_datetime.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }

      it "returns to_date" do
        expect(result).to eq(date_service.to_datetime.to_s)
      end

      context "when subscription is not yet started" do
        let(:started_at) { nil }

        it "returns nil" do
          expect(date_service.charges_to_datetime).to be_nil
        end
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq(date_service.to_datetime.to_s)
        end
      end

      context "when subscription is terminated in the middle of a period" do
        let(:terminated_at) { Time.zone.parse("2022-03-06T12:23:00") }

        before do
          subscription.update!(status: :terminated, terminated_at:)
        end

        it "returns the terminated date" do
          expect(result).to eq(subscription.terminated_at.utc.to_s)
        end

        context "when subscription was upgraded" do
          before do
            create(
              :subscription,
              started_at: terminated_at,
              previous_subscription: subscription
            )
          end

          it "returns the terminated_at" do
            expect(result).to eq(subscription.terminated_at.to_s)
          end

          context "when end of previous day is before charges_from_datetime" do
            let(:started_at) { Time.zone.parse("2022-03-06T10:23:00") }
            let(:terminated_at) { Time.zone.parse("2022-03-06T12:23:00") }

            it "returns the charges_from_datetime" do
              expect(result).to eq(subscription.terminated_at.to_s)
            end
          end
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        it "returns the end of the previous period" do
          expect(result).to eq((date_service.from_datetime - 1.day).end_of_day.to_s)
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 Mar 2022") }

      it "returns to_date" do
        expect(result).to eq(date_service.to_datetime.to_s)
      end

      context "when subscription is terminated in the middle of a period" do
        let(:terminated_at) { Time.zone.parse("1 Mar 2022") }

        before { subscription.mark_as_terminated!(terminated_at) }

        it "returns the terminated date" do
          expect(result).to eq(subscription.terminated_at.utc.to_s)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        it "returns the end of the previous period" do
          expect(result).to eq((date_service.from_datetime - 1.day).end_of_day.to_s)
        end
      end
    end
  end

  describe "#fixed_charges_from_datetime" do
    subject(:result) { date_service.fixed_charges_from_datetime }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Mar 2022") }

      it "returns from_datetime" do
        expect(result).to eq(date_service.from_datetime)
      end

      context "when subscription is not yet started" do
        let(:started_at) { nil }

        it "returns nil" do
          expect(result).to be_nil
        end
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account and returns from_datetime" do
          expect(result).to eq(date_service.from_datetime)
        end

        context "when timezone has changed" do
          let(:billing_at) { Time.zone.parse("02 Mar 2022") }

          let(:previous_invoice_subscription) do
            create(
              :invoice_subscription,
              subscription:,
              fixed_charges_to_datetime: "2022-01-31T23:59:59Z"
            )
          end

          before do
            previous_invoice_subscription
            subscription.customer.update!(timezone: "America/Los_Angeles")
          end

          it "takes previous invoice into account and returns from_datetime" do
            expect(result.to_s).to match_datetime("2022-02-01 00:00:00")
          end
        end

        context "when timezone has changed and there are no invoices generated in the past" do
          let(:billing_at) { Time.zone.parse("02 Mar 2022") }

          before do
            subscription.customer.update!(timezone: "America/Los_Angeles")
          end

          it "takes calculates correct datetime" do
            expect(result).to eq(date_service.from_datetime)
          end
        end
      end

      context "when subscription started in the middle of a period" do
        let(:started_at) { Time.zone.parse("03 Mar 2022") }

        it "returns the start date" do
          expect(result).to eq(subscription.started_at.utc)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }
        let(:subscription_at) { Time.zone.parse("02 Feb 2020") }

        it "returns the start of the previous period" do
          expect(result.to_s).to eq("2022-02-01 00:00:00 UTC")
        end
      end

      context "when previous subscription is upgraded" do
        let(:started_at) { Time.zone.parse("2024-02-22T16:13:00") }

        before do
          create(
            :subscription,
            :terminated,
            terminated_at: started_at
          )
        end

        it "returns the beginning of the start date" do
          expect(result).to eq(subscription.started_at.utc) # boundary should be terminated_at
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 Mar 2022") }

      it "returns from_datetime" do
        expect(result).to eq(date_service.from_datetime)
      end

      context "when subscription started in the middle of a period" do
        let(:started_at) { Time.zone.parse("03 Mar 2022") }

        it "returns the start date" do
          expect(result).to eq(subscription.started_at.utc)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }
        let(:subscription_at) { Time.zone.parse("02 Feb 2020") }

        it "returns the start of the previous period" do
          expect(result.to_s).to eq("2022-02-02 00:00:00 UTC")
        end
      end
    end
  end

  describe "#fixed_charges_to_datetime" do
    subject(:result) { date_service.fixed_charges_to_datetime }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }

      it "returns to_datetime" do
        expect(result).to eq(date_service.to_datetime)
      end

      context "when subscription is not yet started" do
        let(:started_at) { nil }

        it "returns nil" do
          expect(result).to be_nil
        end
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq(date_service.to_datetime)
        end
      end

      context "when subscription is terminated in the middle of a period" do
        let(:terminated_at) { Time.zone.parse("2022-03-06T12:23:00") }

        before do
          subscription.update!(status: :terminated, terminated_at:)
        end

        it "returns the terminated date" do
          expect(result).to eq(subscription.terminated_at.utc)
        end

        context "when subscription was upgraded" do
          before do
            create(
              :subscription,
              started_at: terminated_at,
              previous_subscription: subscription
            )
          end

          it "returns the terminated_at" do
            expect(result).to eq(subscription.terminated_at)
          end

          context "when end of previous day is before fixed_charges_from_datetime" do
            let(:started_at) { Time.zone.parse("2022-03-06T10:23:00") }
            let(:terminated_at) { Time.zone.parse("2022-03-06T12:23:00") }

            it "returns the fixed_charges_from_datetime" do
              expect(result).to eq(subscription.terminated_at)
            end
          end
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        it "returns the end of the previous period" do
          expect(result).to eq((date_service.from_datetime - 1.day).end_of_day)
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 Mar 2022") }

      it "returns to_datetime" do
        expect(result).to eq(date_service.to_datetime)
      end

      context "when subscription is terminated in the middle of a period" do
        let(:terminated_at) { Time.zone.parse("1 Mar 2022") }

        before { subscription.mark_as_terminated!(terminated_at) }

        it "returns the terminated date" do
          expect(result).to eq(subscription.terminated_at.utc)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        it "returns the end of the previous period" do
          expect(result).to eq((date_service.from_datetime - 1.day).end_of_day)
        end
      end
    end
  end

  describe "#next_end_of_period" do
    let(:result) { date_service.next_end_of_period.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }

      it "returns the last day of the month" do
        expect(result).to eq("2022-03-31 23:59:59 UTC")
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-04-01 03:59:59 UTC")
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }

      it "returns the end of the billing month" do
        expect(result).to eq("2022-04-01 23:59:59 UTC")
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-04-01 03:59:59 UTC")
        end
      end

      context "when end of billing month is in next year" do
        let(:billing_at) { Time.zone.parse("07 Dec 2021") }

        it { expect(result).to eq("2022-01-01 23:59:59 UTC") }
      end

      context "when date is the end of the period" do
        let(:billing_at) { Time.zone.parse("01 Mar 2022") }

        it "returns the date" do
          expect(result).to eq(billing_at.utc.end_of_day.to_s)
        end
      end
    end
  end

  describe "#previous_beginning_of_period" do
    let(:result) { date_service.previous_beginning_of_period(current_period:).to_s }

    let(:current_period) { false }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }

      it "returns the first day of the previous month" do
        expect(result).to eq("2022-02-01 00:00:00 UTC")
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-02-01 05:00:00 UTC")
        end
      end

      context "with current period argument" do
        let(:current_period) { true }

        it "returns the first day of the month" do
          expect(result).to eq("2022-03-01 00:00:00 UTC")
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }

      it "returns the beginning of the previous period" do
        expect(result).to eq("2022-02-02 00:00:00 UTC")
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-02-01 05:00:00 UTC")
        end
      end

      context "with current period argument" do
        let(:current_period) { true }

        it "returns the beginning of the current period" do
          expect(result).to eq("2022-03-02 00:00:00 UTC")
        end
      end
    end
  end

  describe "#single_day_price" do
    let(:result) { date_service.single_day_price }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }

      it "returns the price of single day" do
        expect(result).to eq(plan.amount_cents.fdiv(28))
      end

      context "when passing the plan amount" do
        let(:result) { date_service.single_day_price(plan_amount_cents: 1000) }

        it "returns the price of single day" do
          expect(result).to eq(1_000.fdiv(28))
        end
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("28 Feb 2019") }
        let(:billing_at) { Time.zone.parse("01 Mar 2020") }

        it "returns the price of single day" do
          expect(result).to eq(plan.amount_cents.fdiv(29))
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }

      it "returns the price of single day" do
        expect(result).to eq(plan.amount_cents.fdiv(28))
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("02 Feb 2019") }
        let(:billing_at) { Time.zone.parse("08 Mar 2020") }

        it "returns the price of single day" do
          expect(result).to eq(plan.amount_cents.fdiv(29))
        end
      end
    end
  end

  describe "#charges_duration_in_days" do
    let(:result) { date_service.charges_duration_in_days }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }

      it "returns the month duration" do
        expect(result).to eq(28)
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("28 Feb 2019") }
        let(:billing_at) { Time.zone.parse("01 Mar 2020") }

        it "returns the month duration" do
          expect(result).to eq(29)
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }

      it "returns the month duration" do
        expect(result).to eq(28)
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("02 Feb 2019") }
        let(:billing_at) { Time.zone.parse("08 Mar 2020") }

        it "returns the month duration" do
          expect(result).to eq(29)
        end
      end
    end
  end

  describe "#fixed_charges_duration_in_days" do
    subject(:result) { date_service.fixed_charges_duration_in_days }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }

      it "returns the month duration" do
        expect(result).to eq(28)
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("28 Feb 2019") }
        let(:billing_at) { Time.zone.parse("01 Mar 2020") }

        it "returns the month duration" do
          expect(result).to eq(29)
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }

      it "returns the month duration" do
        expect(result).to eq(28)
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("02 Feb 2019") }
        let(:billing_at) { Time.zone.parse("08 Mar 2020") }

        it "returns the month duration" do
          expect(result).to eq(29)
        end
      end
    end
  end

  # In February 2022, customer changed timezone from Asia/Tokyo to America/Los_Angeles.
  # The invoice generated in February 2022 had subscription from Feb 1st to Feb 28th
  # and usage-based charges from Jan 1st to Jan 31st.
  # The dates are correct but *they are in customer timezone*: "2022-01-31 23:59:59 Asia/Tokyo" is "2022-01-31 14:59:59 UTC"
  # In Feb, if we use "2022-02-01 00:00:00 America/Los_Angeles", which is "2022-02-01 07:00:00 UTC" we're now missing
  # all events between "2022-01-31 14:59:59 UTC" and "2022-02-01 07:00:00 UTC", which is a 16h gap.
  #
  # We need to use the previous invoice charges_to_datetime as the new invoice charges_from_datetime.
  #
  #
  context "when customer changed timezone" do
    let(:organization) { create(:organization) }
    let(:billing_entity) { create(:billing_entity, organization:, invoice_grace_period: 3) }
    let(:customer) { create(:customer, timezone:, billing_entity:, organization:) }
    let(:plan) { create(:plan, interval: :monthly, pay_in_advance:, organization:) }

    let(:billing_time) { :calendar }
    let(:timezone) { "Asia/Tokyo" }
    let(:new_timezone) { "America/Los_Angeles" }

    # Clock::SubscriptionsBillerJob will find this subscription as soon as it's March in the customer timezone
    let(:billing_at) { Time.new(2022, 3, 1, 0, 10, 0, Time.new(2022, 3, 1, 0, 10, 0).in_time_zone(new_timezone).formatted_offset) }
    let(:previous_invoice_charges_to_datetime) { Time.new(2022, 1, 31, 23, 59, 59, Time.new(2022, 1, 31, 23, 59, 59).in_time_zone(timezone).formatted_offset) }

    let(:previous_invoice_subscription) do
      create(
        :invoice_subscription,
        subscription:,
        charges_to_datetime: previous_invoice_charges_to_datetime,
        invoice: create(:invoice, timezone: timezone)
      )
    end

    before do
      previous_invoice_subscription
    end

    it "takes previous invoice charges_to_datetime into account and compute correct following month" do
      expect(previous_invoice_subscription.charges_to_datetime).to be_utc
      expect(date_service.send(:timezone_has_changed?)).to be_falsey

      result = Invoices::SubscriptionService.call(
        subscriptions: [subscription],
        timestamp: billing_at.to_i,
        invoicing_reason: "subscription_periodic",
        invoice: nil,
        skip_charges: false
      )

      expect(result.invoice.status).to eq "draft"
      invoice_sub = result.invoice.invoice_subscriptions.first
      expect(invoice_sub.charges_from_datetime.to_s).to match_datetime("2022-01-31 15:00:00 UTC")
      expect(invoice_sub.charges_to_datetime.to_s).to match_datetime("2022-02-28 14:59:59 UTC")

      subscription.customer.update!(timezone: new_timezone)

      finalized_result = Invoices::RefreshDraftAndFinalizeService.call(invoice: result.invoice.reload)
      invoice_sub = finalized_result.invoice.reload.invoice_subscriptions.first

      expect(invoice_sub.charges_from_datetime.to_s).to match_datetime("2022-01-31 15:00:00 UTC")
      # "2022-02-28 23:59:59 America/Los_Angeles" which is "2022-03-01 07:59:59 UTC"
      expect(invoice_sub.charges_to_datetime.to_s).to match_datetime("2022-03-01 07:59:59 UTC")
    end
  end
end
