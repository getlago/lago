# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscriptions::Dates::QuarterlyService do
  subject(:date_service) { described_class.new(subscription, billing_at, current_usage) }

  let(:subscription) do
    create(
      :subscription,
      plan:,
      customer:,
      subscription_at:,
      billing_time:,
      started_at:
    )
  end

  let(:customer) { create(:customer, timezone:) }
  let(:plan) { create(:plan, interval: :monthly, pay_in_advance:) }
  let(:pay_in_advance) { false }
  let(:current_usage) { false }

  let(:subscription_at) { Time.zone.parse("02 Feb 2021") }
  let(:billing_at) { Time.zone.parse("07 Mar 2022") }
  let(:started_at) { subscription_at }
  let(:timezone) { "UTC" }

  describe "from_datetime" do
    let(:result) { date_service.from_datetime.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Jul 2022") }

      it "returns the beginning of the previous quarter" do
        expect(result).to eq("2022-04-01 00:00:00 UTC")
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
        let(:started_at) { Time.zone.parse("07 Apr 2022") }

        it "returns the start date" do
          expect(result).to eq(started_at.beginning_of_day.utc.to_s)
        end

        context "with customer timezone" do
          let(:timezone) { "America/New_York" }

          it "returns the start date in the timezone" do
            expect(result).to eq("2022-04-06 04:00:00 UTC")
          end
        end
      end

      context "when subscription is just terminated" do
        let(:billing_at) { Time.zone.parse("10 Jul 2022") }

        before { subscription.mark_as_terminated!("9 Jul 2022") }

        it "returns the beginning of the quarter" do
          expect(result).to eq("2022-07-01 00:00:00 UTC")
        end

        context "when plan is pay in advance" do
          let(:pay_in_advance) { true }

          it "returns the beginning of the quarter" do
            expect(result).to eq("2022-07-01 00:00:00 UTC")
          end
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 May 2022") }

      it "returns the same day in the previous quarter" do
        expect(result).to eq("2022-02-02 00:00:00 UTC")
      end

      context "when date is before the start date" do
        let(:started_at) { Time.zone.parse("08 Feb 2022") }

        it "returns the start date" do
          expect(result).to eq(started_at.utc.to_s)
        end
      end

      context "when date is in first quarter" do
        let(:billing_at) { Time.zone.parse("02 Feb 2022") }

        it "returns the correct day in the previous year" do
          expect(result).to eq("2021-11-02 00:00:00 UTC")
        end
      end

      context "when date is on the last day of the month" do
        let(:billing_at) { Time.zone.parse("31 May 2022") }
        let(:subscription_at) { Time.zone.parse("28 Feb 2021") }

        it "returns the last day in the previous quarter" do
          expect(result).to eq("2022-02-28 00:00:00 UTC")
        end
      end

      context "when subscription is just terminated" do
        let(:billing_at) { Time.zone.parse("10 May 2022") }

        before { subscription.mark_as_terminated!("9 May 2022") }

        it "returns the correct day at the beginning of the quarter" do
          expect(result).to eq("2022-05-02 00:00:00 UTC")
        end

        context "when plan is pay in advance" do
          let(:pay_in_advance) { true }

          it "returns the correct day in the current quarter" do
            expect(result).to eq("2022-05-02 00:00:00 UTC")
          end
        end

        context "when billing day after last day of billing month" do
          let(:billing_at) { Time.zone.parse("29 May 2022") }
          let(:subscription_at) { Time.zone.parse("30 May 2021") }

          it "returns the previous quarter last day" do
            expect(result).to eq("2022-02-28 00:00:00 UTC")
          end
        end

        context "when billing day in the second month of the year" do
          let(:billing_at) { Time.zone.parse("27 Feb 2022") }
          let(:subscription_at) { Time.zone.parse("28 Feb 2021") }

          before { subscription.mark_as_terminated!("25 Feb 2022") }

          it "returns the previous quarter last day" do
            expect(result).to eq("2021-11-28 00:00:00 UTC")
          end
        end
      end

      context "when plan is in advance and date is on the last day of month" do
        let(:pay_in_advance) { true }

        let(:billing_at) { Time.zone.parse("30 Apr 2021") }
        let(:subscription_at) { Time.zone.parse("31 Jan 2021") }

        it "returns the current day" do
          expect(result).to eq("2021-04-30 00:00:00 UTC")
        end
      end

      context "when date is not on a billing month" do
        let(:billing_at) { Time.zone.parse("8 Aug 2023") }
        let(:subscription_at) { Time.zone.parse("6 Apr 2023") }
        let(:current_usage) { true }

        it "returns the date in previous billing month" do
          expect(result).to eq("2023-07-06 00:00:00 UTC")
        end
      end

      context "when date is not on a billing month and day is less than subscription day" do
        let(:billing_at) { Time.zone.parse("4 Aug 2023") }
        let(:subscription_at) { Time.zone.parse("6 Apr 2023") }
        let(:current_usage) { true }

        it "returns the date in previous billing month" do
          expect(result).to eq("2023-07-06 00:00:00 UTC")
        end
      end
    end
  end

  describe "to_datetime" do
    let(:result) { date_service.to_datetime.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Jul 2022") }

      it "returns the end of the previous quarter" do
        expect(result).to eq("2022-06-30 23:59:59 UTC")
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
          expect(result).to eq("2022-04-01 03:59:59 UTC")
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        it "returns the end of the quarter" do
          expect(result).to eq("2022-09-30 23:59:59 UTC")
        end
      end

      context "when subscription is just terminated" do
        let(:billing_at) { Time.zone.parse("01 Jul 2022") }

        before do
          subscription.update!(
            status: :terminated,
            terminated_at: Time.zone.parse("27 Jun 2022")
          )
        end

        it "returns the termination date" do
          expect(result).to match_datetime(subscription.terminated_at.utc)
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
      let(:billing_at) { Time.zone.parse("02 May 2022") }

      it "returns the day in the previous month" do
        expect(result).to eq("2022-05-01 23:59:59 UTC")
      end

      context "when billing last quarter of the year" do
        let(:billing_at) { Time.zone.parse("02 Feb 2022") }

        it "returns the day in the previous month" do
          expect(result).to eq("2022-02-01 23:59:59 UTC")
        end
      end

      context "when billing subscription day does not exist in the month" do
        let(:subscription_at) { Time.zone.parse("30 Nov 2021") }
        let(:billing_at) { Time.zone.parse("01 Mar 2022") }

        it "returns the last day of the previous month" do
          expect(result).to eq("2022-02-27 23:59:59 UTC")
        end

        context "when subscription is not the last day of the month" do
          let(:subscription_at) { Time.zone.parse("30 Jan 2022") }
          let(:billing_at) { Time.zone.parse("30 Apr 2022") }

          it "returns the last day of the month" do
            expect(result).to eq("2022-04-29 23:59:59 UTC")
          end
        end
      end

      context "when anniversary date is first day of the quarter" do
        let(:subscription_at) { Time.zone.parse("01 Oct 2021") }
        let(:billing_at) { Time.zone.parse("02 Apr 2022") }

        it "returns the last day of the previous quarter" do
          expect(result).to eq("2022-03-31 23:59:59 UTC")
        end
      end

      context "when plan is pay in advance" do
        before { plan.update!(pay_in_advance: true) }

        it "returns the end of the current period" do
          expect(result).to eq("2022-08-01 23:59:59 UTC")
        end
      end

      context "when subscription is just terminated" do
        before do
          subscription.update!(
            status: :terminated,
            terminated_at: Time.zone.parse("30 Apr 2022")
          )
        end

        it "returns the termination date" do
          expect(result).to match_datetime(subscription.terminated_at.utc)
        end
      end
    end
  end

  describe "charges_from_datetime" do
    let(:result) { date_service.charges_from_datetime.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Apr 2022") }

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
          let(:billing_at) { Time.zone.parse("02 Apr 2022") }

          let(:previous_invoice_subscription) do
            create(
              :invoice_subscription,
              subscription:,
              charges_to_datetime: "2021-12-31T23:59:59Z"
            )
          end

          before do
            previous_invoice_subscription
            subscription.customer.update!(timezone: "America/Los_Angeles")
          end

          it "takes previous invoice into account" do
            expect(result).to match_datetime("2022-01-01 00:00:00")
          end
        end
      end

      context "when subscription started in the middle of a period" do
        let(:started_at) { Time.zone.parse("03 Apr 2022") }

        it "returns the start date" do
          expect(result).to eq(subscription.started_at.utc.to_s)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }
        let(:subscription_at) { Time.zone.parse("01 Jan 2020") }

        it "returns the start of the previous period" do
          expect(result).to eq("2022-01-01 00:00:00 UTC")
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 May 2022") }

      it "returns from_datetime" do
        expect(result).to eq(date_service.from_datetime.to_s)
      end

      context "when subscription started in the middle of a period" do
        let(:started_at) { Time.zone.parse("03 May 2022") }

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

  describe "charges_to_datetime" do
    let(:result) { date_service.charges_to_datetime.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Jul 2022") }

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
        let(:terminated_at) { Time.zone.parse("15 Jun 2022") }

        before do
          subscription.update!(status: :terminated, terminated_at:)
        end

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

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 May 2022") }

      it "returns to_date" do
        expect(result).to eq(date_service.to_datetime.to_s)
      end

      context "when subscription is terminated in the middle of a period" do
        let(:terminated_at) { Time.zone.parse("15 Apr 2022") }

        before do
          subscription.update!(status: :terminated, terminated_at:)
        end

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
      let(:billing_at) { Time.zone.parse("01 Apr 2022") }

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
          let(:billing_at) { Time.zone.parse("02 Apr 2022") }

          let(:previous_invoice_subscription) do
            create(
              :invoice_subscription,
              subscription:,
              fixed_charges_to_datetime: "2021-12-31T23:59:59Z"
            )
          end

          before do
            previous_invoice_subscription
            subscription.customer.update!(timezone: "America/Los_Angeles")
          end

          it "takes previous invoice into account and returns from_datetime" do
            expect(result.to_s).to match_datetime("2022-01-01 00:00:00")
          end
        end

        context "when timezone has changed and there are no invoices generated in the past" do
          let(:billing_at) { Time.zone.parse("02 Apr 2022") }

          before do
            subscription.customer.update!(timezone: "America/Los_Angeles")
          end

          it "takes calculates correct datetime" do
            expect(result).to eq(date_service.from_datetime)
          end
        end
      end

      context "when subscription started in the middle of a period" do
        let(:started_at) { Time.zone.parse("03 Apr 2022") }

        it "returns the start date" do
          expect(result).to eq(subscription.started_at.utc)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }
        let(:subscription_at) { Time.zone.parse("01 Jan 2020") }

        it "returns the start of the previous period" do
          expect(result.to_s).to eq("2022-01-01 00:00:00 UTC")
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
      let(:billing_at) { Time.zone.parse("02 May 2022") }

      it "returns from_datetime" do
        expect(result).to eq(date_service.from_datetime)
      end

      context "when subscription started in the middle of a period" do
        let(:started_at) { Time.zone.parse("03 May 2022") }

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
      let(:billing_at) { Time.zone.parse("01 Jul 2022") }

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
        let(:terminated_at) { Time.zone.parse("2022-06-15T12:23:00") }

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
      let(:billing_at) { Time.zone.parse("02 May 2022") }

      it "returns to_datetime" do
        expect(result).to eq(date_service.to_datetime)
      end

      context "when subscription is terminated in the middle of a period" do
        let(:terminated_at) { Time.zone.parse("15 Apr 2022") }

        before do
          subscription.update!(status: :terminated, terminated_at:)
        end

        it "returns the terminated date" do
          expect(result).to eq(subscription.terminated_at.utc)
        end
      end

      context "when plan is pay in advance" do
        let(:pay_in_advance) { true }

        # FAILS
        it "returns the end of the previous period" do
          expect(result).to eq((date_service.from_datetime - 1.day).end_of_day)
        end
      end
    end
  end

  describe "next_end_of_period" do
    let(:result) { date_service.next_end_of_period.to_s }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("02 Jul 2022") }

      it "returns the last day of the month" do
        expect(result).to eq("2022-09-30 23:59:59 UTC")
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-10-01 03:59:59 UTC")
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("07 May 2022") }

      it "returns the end of the billing month" do
        expect(result).to eq("2022-08-01 23:59:59 UTC")
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-08-01 03:59:59 UTC")
        end
      end

      context "when end of billing month is in next year" do
        let(:billing_at) { Time.zone.parse("02 Nov 2021") }

        it { expect(result).to eq("2022-02-01 23:59:59 UTC") }
      end

      context "when date is the end of the period" do
        let(:billing_at) { Time.zone.parse("01 May 2022") }

        it "returns the date" do
          expect(result).to eq(billing_at.utc.end_of_day.to_s)
        end
      end
    end
  end

  describe "previous_beginning_of_period" do
    let(:result) { date_service.previous_beginning_of_period(current_period:).to_s }

    let(:current_period) { false }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("02 Jul 2022") }

      it "returns the first day of the previous month" do
        expect(result).to eq("2022-04-01 00:00:00 UTC")
      end

      context "with customer timezone" do
        let(:timezone) { "America/New_York" }

        it "takes customer timezone into account" do
          expect(result).to eq("2022-04-01 04:00:00 UTC")
        end
      end

      context "with current period argument" do
        let(:current_period) { true }

        it "returns the first day of the month" do
          expect(result).to eq("2022-07-01 00:00:00 UTC")
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("03 May 2022") }

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
          expect(result).to eq("2022-05-02 00:00:00 UTC")
        end
      end
    end
  end

  describe "single_day_price" do
    let(:result) { date_service.single_day_price }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Jul 2022") }

      it "returns the price of single day" do
        expect(result).to eq(plan.amount_cents.fdiv(91))
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("28 Feb 2019") }
        let(:billing_at) { Time.zone.parse("01 Apr 2020") }

        it "returns the price of single day" do
          expect(result).to eq(plan.amount_cents.fdiv(91))
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 May 2020") }

      it "returns the price of single day" do
        expect(result).to eq(plan.amount_cents.fdiv(90))
      end

      context "when not on a leap year" do
        let(:billing_at) { Time.zone.parse("02 May 2021") }

        it "returns the month duration" do
          expect(result).to eq(plan.amount_cents.fdiv(89))
        end
      end
    end
  end

  describe "charges_duration_in_days" do
    let(:result) { date_service.charges_duration_in_days }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Jul 2022") }

      it "returns the quarter duration" do
        expect(result).to eq(91)
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("28 Feb 2019") }
        let(:billing_at) { Time.zone.parse("01 Apr 2020") }

        it "returns the duration in days" do
          expect(result).to eq(91)
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 May 2020") }

      it "returns the month duration" do
        expect(result).to eq(90)
      end

      context "when not on a leap year" do
        let(:subscription_at) { Time.zone.parse("02 Feb 2019") }
        let(:billing_at) { Time.zone.parse("02 May 2021") }

        it "returns the duration in days" do
          expect(result).to eq(89)
        end
      end
    end
  end

  describe "fixed_charges_duration_in_days" do
    subject(:result) { date_service.fixed_charges_duration_in_days }

    context "when billing_time is calendar" do
      let(:billing_time) { :calendar }
      let(:billing_at) { Time.zone.parse("01 Jul 2022") }

      it "returns the quarter duration" do
        expect(result).to eq(91)
      end

      context "when on a leap year" do
        let(:subscription_at) { Time.zone.parse("28 Feb 2019") }
        let(:billing_at) { Time.zone.parse("01 Apr 2020") }

        it "returns the duration in days" do
          expect(result).to eq(91)
        end
      end
    end

    context "when billing_time is anniversary" do
      let(:billing_time) { :anniversary }
      let(:billing_at) { Time.zone.parse("02 May 2020") }

      it "returns the month duration" do
        expect(result).to eq(90)
      end

      context "when not on a leap year" do
        let(:subscription_at) { Time.zone.parse("02 Feb 2019") }
        let(:billing_at) { Time.zone.parse("02 May 2021") }

        it "returns the duration in days" do
          expect(result).to eq(89)
        end
      end
    end
  end
end
