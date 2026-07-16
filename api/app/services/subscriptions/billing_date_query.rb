# frozen_string_literal: true

module Subscriptions
  # Filters a subscriptions scope down to the ones whose billing period rolls over (i.e. is billed)
  # on `timestamp`'s date, in the customer's applicable timezone.
  #
  # The calendar logic (calendar vs anniversary, every interval, end-of-month and leap-year edge
  # cases, timezone) is intentionally identical to the periodic billing selection in
  # `Subscriptions::OrganizationBillingService#billable_subscriptions`. It is expressed here as a
  # single OR-ed WHERE so it can be composed onto any subscriptions scope.
  #
  # NOTE: the given scope must allow joining `:plan` and `customer: :billing_entity` (needed for the
  #       timezone-aware date comparisons).
  class BillingDateQuery < BaseService
    Result = BaseResult[:subscriptions]

    def initialize(subscriptions:, timestamp:)
      @subscriptions = subscriptions
      @timestamp = timestamp

      super
    end

    def call
      result.subscriptions = subscriptions
        .joins(:plan, customer: :billing_entity)
        .where(billing_day_conditions, today: timestamp)

      result
    end

    private

    attr_reader :subscriptions, :timestamp

    def billing_day_conditions
      [
        scoped(:calendar, :weekly, weekly_calendar),
        scoped(:calendar, :monthly, monthly_calendar),
        scoped(:calendar, :quarterly, quarterly_calendar),
        scoped(:calendar, :semiannual, semiannual_with_monthly_charges),
        scoped(:calendar, :semiannual, semiannual_with_monthly_fixed_charges),
        scoped(:calendar, :semiannual, semiannual_calendar),
        scoped(:calendar, :yearly, yearly_with_monthly_charges),
        scoped(:calendar, :yearly, yearly_with_monthly_fixed_charges),
        scoped(:calendar, :yearly, yearly_calendar),
        scoped(:anniversary, :weekly, weekly_anniversary),
        scoped(:anniversary, :monthly, anniversary_day),
        scoped(:anniversary, :quarterly, "#{quarterly_anniversary_month} AND #{anniversary_day}"),
        scoped(:anniversary, :semiannual, "#{plan_bill_charges_monthly} AND #{anniversary_day}"),
        scoped(:anniversary, :semiannual, "#{plan_bill_fixed_charges_monthly_only} AND #{anniversary_day}"),
        scoped(:anniversary, :semiannual, "#{semiannual_anniversary_month} AND #{anniversary_day}"),
        scoped(:anniversary, :yearly, "#{plan_bill_charges_monthly} AND #{anniversary_day}"),
        scoped(:anniversary, :yearly, "#{plan_bill_fixed_charges_monthly_only} AND #{anniversary_day}"),
        scoped(:anniversary, :yearly, "#{yearly_anniversary_month} AND #{yearly_anniversary_day}")
      ].map { |condition| "(#{condition})" }.join(" OR ")
    end

    def scoped(billing_time, interval, condition)
      "subscriptions.billing_time = #{Subscription.billing_times[billing_time]} " \
        "AND plans.interval = #{Plan.intervals[interval]} " \
        "AND (#{condition})"
    end

    def tz
      @tz ||= at_time_zone
    end

    def weekly_calendar
      "EXTRACT(ISODOW FROM (:today#{tz})) = 1"
    end

    def monthly_calendar
      "DATE_PART('day', (:today#{tz})) = 1"
    end

    def quarterly_calendar
      "DATE_PART('month', (:today#{tz})) IN (1, 4, 7, 10) AND DATE_PART('day', (:today#{tz})) = 1"
    end

    def semiannual_calendar
      "DATE_PART('month', (:today#{tz})) IN (1, 7) AND DATE_PART('day', (:today#{tz})) = 1"
    end

    def yearly_calendar
      "DATE_PART('month', (:today#{tz})) = 1 AND DATE_PART('day', (:today#{tz})) = 1"
    end

    def semiannual_with_monthly_charges
      "DATE_PART('day', (:today#{tz})) = 1 AND #{plan_bill_charges_monthly}"
    end

    def semiannual_with_monthly_fixed_charges
      "DATE_PART('day', (:today#{tz})) = 1 AND #{plan_bill_fixed_charges_monthly_only}"
    end

    def yearly_with_monthly_charges
      "DATE_PART('day', (:today#{tz})) = 1 AND #{plan_bill_charges_monthly}"
    end

    def yearly_with_monthly_fixed_charges
      "DATE_PART('day', (:today#{tz})) = 1 AND #{plan_bill_fixed_charges_monthly_only}"
    end

    def weekly_anniversary
      "EXTRACT(ISODOW FROM (subscriptions.subscription_at#{tz})) = EXTRACT(ISODOW FROM (:today#{tz}))"
    end

    # The subscription_at day-of-month matches today, accounting for short months (e.g. a sub
    # anchored on the 31st bills on the 30th/28th when the month is shorter).
    def anniversary_day
      <<~SQL.squish
        DATE_PART('day', (subscriptions.subscription_at#{tz})) = ANY (
          CASE WHEN DATE_PART('day', (#{end_of_month})) = DATE_PART('day', :today#{tz})
          THEN
            (SELECT ARRAY(SELECT generate_series(DATE_PART('day', :today#{tz})::integer, 31)))
          ELSE
            (SELECT ARRAY[DATE_PART('day', :today#{tz})])
          END
        )
      SQL
    end

    def quarterly_anniversary_month
      <<~SQL.squish
        (
          CASE WHEN MOD(CAST(DATE_PART('month', (subscriptions.subscription_at#{tz})) AS INTEGER), 3) = 0
          THEN
            (DATE_PART('month', :today#{tz}) IN (3, 6, 9, 12))
          ELSE (
            DATE_PART('month', (subscriptions.subscription_at#{tz})) = DATE_PART('month', :today#{tz})
              OR MOD(CAST(DATE_PART('month', (subscriptions.subscription_at#{tz})) + 3 AS INTEGER), 12) = DATE_PART('month', :today#{tz})
              OR MOD(CAST(DATE_PART('month', (subscriptions.subscription_at#{tz})) + 6 AS INTEGER), 12) = DATE_PART('month', :today#{tz})
              OR MOD(CAST(DATE_PART('month', (subscriptions.subscription_at#{tz})) + 9 AS INTEGER), 12) = DATE_PART('month', :today#{tz})
          )
          END
        )
      SQL
    end

    def semiannual_anniversary_month
      <<~SQL.squish
        (
          CASE WHEN MOD(CAST(DATE_PART('month', (subscriptions.subscription_at#{tz})) AS INTEGER), 6) = 0
          THEN
            (DATE_PART('month', :today#{tz}) IN (6, 12))
          ELSE (
            DATE_PART('month', (subscriptions.subscription_at#{tz})) = DATE_PART('month', :today#{tz})
              OR MOD(CAST(DATE_PART('month', (subscriptions.subscription_at#{tz})) + 6 AS INTEGER), 12) = DATE_PART('month', :today#{tz})
          )
          END
        )
      SQL
    end

    def yearly_anniversary_month
      "DATE_PART('month', (subscriptions.subscription_at#{tz})) = DATE_PART('month', :today#{tz})"
    end

    def yearly_anniversary_day
      <<~SQL.squish
        DATE_PART('day', (subscriptions.subscription_at#{tz})) = ANY (
          CASE WHEN (
            DATE_PART('month', :today#{tz}) = 2
            AND DATE_PART('day', :today#{tz}) = 28
            AND DATE_PART('day', (#{end_of_month})) = 28
          )
          THEN
            ARRAY[28, 29]
          ELSE
            ARRAY[DATE_PART('day', :today#{tz})]
          END
        )
      SQL
    end

    def plan_bill_charges_monthly
      "plans.bill_charges_monthly = 't'"
    end

    def plan_bill_fixed_charges_monthly_only
      "plans.bill_fixed_charges_monthly = 't' AND (plans.bill_charges_monthly = 'f' OR plans.bill_charges_monthly IS NULL)"
    end

    def end_of_month
      "(DATE_TRUNC('month', :today#{tz}) + INTERVAL '1 month - 1 day')::date"
    end
  end
end
