# frozen_string_literal: true

module Subscriptions
  module Dates
    class YearlyService < Subscriptions::DatesService
      def first_month_in_yearly_period?
        return billing_date.month == 1 if calendar?

        monthly_service.compute_from_date(billing_date).month == subscription_at.month
      end

      def first_month_in_first_yearly_period?
        return billing_date.month == 1 && billing_date.year == subscription_at.year if calendar?

        billing_from_date = monthly_service.compute_from_date(billing_date)
        billing_from_date.month == subscription_at.month && billing_from_date.year == subscription_at.year
      end

      private

      # When computing current usage (not billing), boundaries are always needed.
      # if bill_charges_monthly=true, charge boundaries should be filled
      # if bill_FIXED_charges_monthly=true, charge boundaries should be filled only for the first month of the period
      # For yearly plans with bill_charges_monthly=false, and bill_fixed_charges_monthly=false,
      # boundaries are always filled
      def should_fill_charges_boundaries?
        return true if current_usage
        return true if plan.bill_charges_monthly?

        return first_month_in_yearly_period? if plan.bill_fixed_charges_monthly?

        true
      end

      # if bill_fixed_charges_monthly=true, fixed charge boundaries should be filled
      # if bill_charges_monthly=true, fixed charge boundaries should be filled only for the first month of the period
      # For yearly plans with bill_charges_monthly=false, and bill_fixed_charges_monthly=false,
      # boundaries are always filled
      def should_fill_fixed_charges_boundaries?
        return true if plan.bill_fixed_charges_monthly?

        return first_month_in_yearly_period? if plan.bill_charges_monthly?

        true
      end

      def compute_base_date
        billing_date - 1.year
      end

      def monthly_service
        @monthly_service ||= Subscriptions::Dates::MonthlyService.new(subscription, billing_date, current_usage)
      end

      def compute_from_date
        if plan.pay_in_advance? || terminated_pay_in_arrears?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_year
        end

        subscription.anniversary? ? previous_anniversary_day(base_date) : base_date.beginning_of_year
      end

      def compute_to_date(from_date = compute_from_date)
        return from_date.end_of_year if subscription.calendar? || subscription_at.yday == 1

        year = from_date.year + 1
        month = from_date.month
        day = subscription_at.day - 1

        build_date(year, month, day)
      end

      def compute_charges_from_date
        return monthly_service.compute_charges_from_date if plan.bill_charges_monthly

        if terminated?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_year
        end

        return compute_from_date if plan.pay_in_arrears?
        return base_date.beginning_of_year if calendar?

        previous_anniversary_day(base_date)
      end

      def compute_charges_to_date
        return monthly_service.compute_charges_to_date if plan.bill_charges_monthly
        return compute_charges_from_date.end_of_year if calendar?

        compute_to_date(compute_charges_from_date)
      end

      def compute_fixed_charges_from_date
        return monthly_service.compute_fixed_charges_from_date if plan.bill_fixed_charges_monthly

        if terminated?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_year
        end

        return compute_from_date if plan.pay_in_arrears?
        return base_date.beginning_of_year if calendar?

        previous_anniversary_day(base_date)
      end

      def compute_fixed_charges_to_date
        return monthly_service.compute_fixed_charges_to_date if plan.bill_fixed_charges_monthly
        return compute_fixed_charges_from_date.end_of_year if calendar?

        compute_to_date(compute_fixed_charges_from_date)
      end

      def compute_next_end_of_period
        return billing_date.end_of_year if calendar?

        year = billing_date.year
        month = subscription_at.month
        day = subscription_at.day

        # NOTE: we need the last day of the period, and not the first of the next one
        result_date = build_date(year, month, day) - 1.day
        return result_date if result_date >= billing_date

        build_date(year + 1, month, day) - 1.day
      end

      def compute_previous_beginning_of_period(date)
        return date.beginning_of_year if calendar?

        previous_anniversary_day(date)
      end

      def previous_anniversary_day(date)
        year = period_started_in_last_year?(date) ? (date.year - 1) : date.year
        month = subscription_at.month
        day = subscription_at.day

        build_date(year, month, day)
      end

      def compute_duration(from_date:)
        return Time.days_in_year(from_date.year) if calendar?

        year = from_date.year
        # NOTE: if after February we must check if next year is a leap year
        year += 1 if from_date.month > 2

        Time.days_in_year(year)
      end

      def compute_charges_duration(from_date:)
        return monthly_service.compute_charges_duration(from_date:) if plan.bill_charges_monthly

        compute_duration(from_date:)
      end

      def compute_fixed_charges_duration(from_date:)
        return monthly_service.compute_fixed_charges_duration(from_date:) if plan.bill_fixed_charges_monthly

        compute_duration(from_date:)
      end

      def period_started_in_last_year?(date)
        return true if date.month < subscription_at.month
        return true if (date.month == subscription_at.month) && (date.day < subscription_at.day)

        false
      end
    end
  end
end
