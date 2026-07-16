# frozen_string_literal: true

module Subscriptions
  module Dates
    class WeeklyService < Subscriptions::DatesService
      WEEK_DURATION = 7

      private

      def compute_base_date
        billing_date - 1.week
      end

      def compute_from_date
        if plan.pay_in_advance? || terminated_pay_in_arrears?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_week
        end

        subscription.anniversary? ? previous_anniversary_day(base_date) : base_date.beginning_of_week
      end

      def compute_to_date(from_date = compute_from_date)
        return from_date.end_of_week if calendar?

        from_date + 6.days
      end

      def compute_charges_from_date
        # NOTE: when subscription is terminated, we must bill on the current period
        if terminated?
          return subscription.anniversary? ? previous_anniversary_day(billing_date) : billing_date.beginning_of_week
        end

        return compute_from_date if plan.pay_in_arrears?
        return base_date.beginning_of_week if calendar?

        previous_anniversary_day(base_date)
      end

      def compute_charges_to_date
        return compute_charges_from_date.end_of_week if calendar?

        compute_charges_from_date + 6.days
      end

      def compute_next_end_of_period
        return billing_date.end_of_week if calendar?
        return billing_date if billing_date.wday == (subscription_at - 1.day).wday

        # NOTE: we need the last day of the period, and not the first of the next one
        billing_date.next_occurring(subscription_day_name) - 1.day
      end

      def compute_previous_beginning_of_period(date)
        return date.beginning_of_week if calendar?

        previous_anniversary_day(date)
      end

      def previous_anniversary_day(date)
        return date if date.wday == subscription_at.wday

        date.prev_occurring(subscription_day_name)
      end

      def subscription_day_name
        @subscription_day_name ||= subscription_at.strftime("%A").downcase.to_sym
      end

      def compute_duration(*)
        WEEK_DURATION
      end

      alias_method :compute_charges_duration, :compute_duration
      alias_method :compute_fixed_charges_duration, :compute_charges_duration
      alias_method :compute_fixed_charges_from_date, :compute_charges_from_date
      alias_method :compute_fixed_charges_to_date, :compute_charges_to_date
    end
  end
end
