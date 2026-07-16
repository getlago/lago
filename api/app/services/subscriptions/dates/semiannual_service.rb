# frozen_string_literal: true

module Subscriptions
  module Dates
    class SemiannualService < Subscriptions::DatesService
      def first_month_in_semiannual_period?
        return billing_date.month == 1 || billing_date.month == 7 if calendar?

        start_month = subscription_at.month
        second_half_month = (start_month <= 6) ? start_month + 6 : start_month - 6
        [start_month, second_half_month].include?(billing_from_date.month)
      end

      def first_month_in_first_semiannual_period?
        return (billing_date.month == 1 || billing_date.month == 7) && billing_date.year == subscription_at.year if calendar?

        billing_from_date.month == subscription_at.month && billing_from_date.year == subscription_at.year
      end

      private

      # When computing current usage (not billing), boundaries are always needed.
      # if bill_charges_monthly=true, charge boundaries should be filled
      # else if bill_FIXED_charges_monthly=true, charge boundaries should be filled only for the first month of the period
      # For semiannual plans with not billing charges and fixed charges monthly,
      # boundaries are always filled
      def should_fill_charges_boundaries?
        return true if current_usage
        return true if plan.bill_charges_monthly?

        return first_month_in_semiannual_period? if plan.bill_fixed_charges_monthly?

        true
      end

      # if bill_fixed_charges_monthly=true, fixed charge boundaries should be filled
      # if bill_charges_monthly=true, fixed charge boundaries should be filled only for the first month of the period
      # For semiannual plans with not billing charges and fixed charges mothly,
      # boundaries are always filled
      def should_fill_fixed_charges_boundaries?
        return true if plan.bill_fixed_charges_monthly?

        return first_month_in_semiannual_period? if plan.bill_charges_monthly?

        true
      end

      def monthly_service
        @monthly_service ||= Subscriptions::Dates::MonthlyService.new(subscription, billing_date, current_usage)
      end

      def billing_from_date
        @billing_from_date ||= monthly_service.compute_from_date(billing_date)
      end

      def compute_from_date(date = base_date)
        if plan.pay_in_advance? || terminated_pay_in_arrears?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_half_year
        end

        subscription.anniversary? ? previous_anniversary_day(date) : date.beginning_of_half_year
      end

      def compute_charges_from_date
        return monthly_service.compute_charges_from_date if plan.bill_charges_monthly

        if terminated?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_half_year
        end

        return compute_from_date if plan.pay_in_arrears?
        return base_date.beginning_of_half_year if calendar?

        previous_anniversary_day(base_date)
      end

      def compute_charges_to_date
        return monthly_service.compute_charges_to_date if plan.bill_charges_monthly
        return compute_charges_from_date.end_of_half_year if calendar?

        compute_to_date(compute_charges_from_date)
      end

      def compute_fixed_charges_from_date
        return monthly_service.compute_fixed_charges_from_date if plan.bill_fixed_charges_monthly

        if terminated?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_half_year
        end

        return compute_from_date if plan.pay_in_arrears?
        return base_date.beginning_of_half_year if calendar?

        previous_anniversary_day(base_date)
      end

      def compute_fixed_charges_to_date
        return monthly_service.compute_fixed_charges_to_date if plan.bill_fixed_charges_monthly
        return compute_fixed_charges_from_date.end_of_half_year if calendar?

        compute_to_date(compute_fixed_charges_from_date)
      end

      def compute_duration(from_date:)
        next_to_date = compute_to_date(from_date)

        (next_to_date.to_date + 1.day - from_date.to_date).to_i
      end

      def compute_charges_duration(from_date:)
        return monthly_service.compute_charges_duration(from_date:) if plan.bill_charges_monthly

        compute_duration(from_date:)
      end

      def compute_fixed_charges_duration(from_date:)
        return monthly_service.compute_fixed_charges_duration(from_date:) if plan.bill_fixed_charges_monthly

        compute_duration(from_date:)
      end

      def compute_base_date
        # NOTE: if subscription anniversary is on last day of month and current month days count
        #       is less than month anniversary day count, we need to use the last day of the previous month
        if subscription.anniversary? && last_day_of_month?(billing_date) && (billing_date.day < subscription_at.day)
          if (billing_date - 6.months).end_of_month.day >= subscription_at.day
            return (billing_date - 6.months).end_of_month.change(day: subscription_at.day)
          end

          return (billing_date - 6.months).end_of_month
        end

        billing_date - 6.months
      end

      def compute_to_date(from_date = compute_from_date)
        if subscription.calendar? || (subscription_at.day == 1 && [1, 7].include?(subscription_at.month))
          return from_date.end_of_half_year
        end

        year = from_date.year
        month = from_date.month + 6
        day = subscription_at.day - 1

        if month > 12
          month = (month % 12).zero? ? 12 : (month % 12)
          year += 1
        end

        date = build_date(year, month, day)

        # NOTE: if subscription anniversary day is higher than the current last day of the month,
        #       subscription period, will end on the previous end of day
        return date - 1.day if last_day_of_month?(date) && subscription_at.day > date.day

        date
      end

      def compute_next_end_of_period
        return billing_date.end_of_half_year if calendar?

        year = billing_date.year
        month = billing_date.month
        day = subscription_at.day

        # NOTE: we need the last day of the period, and not the first of the next one
        result_date = build_date(year, month, day) - 1.day
        return result_date if result_date >= billing_date

        month += 6
        if month > 12
          month = (month % 12).zero? ? 12 : (month % 12)
          year += 1
        end

        build_date(year, month, day) - 1.day
      end

      def compute_previous_beginning_of_period(date)
        return date.beginning_of_half_year if calendar?

        previous_anniversary_day(date)
      end

      def previous_anniversary_day(date)
        year = nil
        month = nil

        # NOTE: if subscription anniversary day is higher than the current last day of the month,
        #       anniversary day is on the current day
        day = if subscription.anniversary? && last_day_of_month?(date) && (date.day < subscription_at.day)
          date.day
        else
          subscription_at.day
        end

        billing_months = [
          (subscription_at.month % 12).zero? ? 12 : (subscription_at.month % 12),
          ((subscription_at.month + 6) % 12).zero? ? 12 : ((subscription_at.month + 6) % 12)
        ].sort

        # This is the case when we terminate subscription on On February 10 but anniversary date is on
        # 5 of March. In that case we need to fetch billing period in previous year
        if should_find_billing_date_in_previous_year?(date, billing_months, day)
          year = date.year - 1
          month = billing_months[1]
          day = Time.days_in_month(month, year) if last_day_of_month?(subscription_at)
        # In case of termination that is in the middle of the year, previous period anniversary date has to be returned
        elsif should_find_previous_billing_date?(date, billing_months, day)
          year = date.year
          month = billing_months.rfind { |m| m < date.month }
          day = Time.days_in_month(month, year) if last_day_of_month?(subscription_at)
        else
          year = date.year
          month = date.month
        end

        build_date(year, month, day)
      end

      def should_find_billing_date_in_previous_year?(date, billing_months, day)
        return true if date.month < billing_months[0]

        (date.month == billing_months[0]) && should_find_previous_billing_date?(date, billing_months, day)
      end

      def should_find_previous_billing_date?(date, billing_months, day)
        return false if last_day_of_month?(date) && last_day_of_month?(subscription_at)

        return true if date.day < day && terminated_pay_in_arrears?
        return true if (date.day + 1) < day && last_day_of_month?(subscription_at)
        return true if date.day < day && !last_day_of_month?(subscription_at)
        return true if billing_months.exclude?(date.month)

        false
      end
    end
  end
end
