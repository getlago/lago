# frozen_string_literal: true

module Subscriptions
  module Dates
    class MonthlyService < Subscriptions::DatesService
      def compute_from_date(date = base_date)
        if plan.pay_in_advance? || terminated_pay_in_arrears?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_month
        end

        subscription.anniversary? ? previous_anniversary_day(date) : date.beginning_of_month
      end

      def compute_charges_from_date
        if terminated?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_month
        end

        return compute_from_date if plan.pay_in_arrears?
        return base_date.beginning_of_month if calendar?

        previous_anniversary_day(base_date)
      end

      def compute_charges_to_date
        return compute_charges_from_date.end_of_month if calendar?

        compute_to_date(compute_charges_from_date)
      end

      def compute_duration(from_date:)
        return Time.days_in_month(from_date.month, from_date.year) if calendar?

        next_month_date = compute_to_date(from_date)
        (next_month_date.to_date + 1.day - from_date.to_date).to_i
      end

      alias_method :compute_charges_duration, :compute_duration
      alias_method :compute_fixed_charges_duration, :compute_charges_duration
      alias_method :compute_fixed_charges_from_date, :compute_charges_from_date
      alias_method :compute_fixed_charges_to_date, :compute_charges_to_date

      private

      def compute_base_date
        # NOTE: if subscription anniversary is on last day of month and current month days count
        #       is less than month anniversary day count, we need to use the last day of the previous month
        if subscription.anniversary? && last_day_of_month?(billing_date) && (billing_date.day < subscription_at.day)
          if (billing_date - 1.month).end_of_month.day >= subscription_at.day
            return (billing_date - 1.month).change(day: subscription_at.day)
          end

          return (billing_date - 1.month).end_of_month
        end

        billing_date - 1.month
      end

      def compute_to_date(from_date = compute_from_date)
        return from_date.end_of_month if subscription.calendar? || subscription_at.day == 1

        year = from_date.year
        month = from_date.month + 1
        day = subscription_at.day - 1

        if month > 12
          month = 1
          year += 1
        end

        date = build_date(year, month, day)

        # NOTE: if subscription anniversary day is higher than the current last day of the month,
        #       subscription period, will end on the previous end of day
        return date - 1.day if last_day_of_month?(date) && subscription_at.day > date.day

        date
      end

      def compute_next_end_of_period
        return billing_date.end_of_month if calendar?

        year = billing_date.year
        month = billing_date.month
        day = subscription_at.day

        # NOTE: we need the last day of the period, and not the first of the next one
        result_date = build_date(year, month, day) - 1.day
        return result_date if result_date >= billing_date

        month += 1
        if month > 12
          month = 1
          year += 1
        end

        build_date(year, month, day) - 1.day
      end

      def compute_previous_beginning_of_period(date)
        return date.beginning_of_month if calendar?

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

        if date.day < day
          year = (date.month == 1) ? date.year - 1 : date.year
          month = (date.month == 1) ? 12 : date.month - 1
        else
          year = date.year
          month = date.month
        end

        build_date(year, month, day)
      end
    end
  end
end
