# frozen_string_literal: true

module DailyUsages
  class ComputeAllService < BaseService
    ENQUEUE_BATCH_SIZE = 1_000

    Result = BaseResult

    def initialize(timestamp: Time.current)
      @timestamp = timestamp

      super
    end

    def call
      Organization.with_revenue_analytics_support.find_each do |organization|
        ids = Set.new

        # Each leg runs its (cheap, indexed) selection query ONCE via pluck. We never iterate the
        # heavy relation with find_each, which would re-execute the whole query per 1000-row batch.
        ids.merge(event_subscriptions(organization).pluck("subscriptions.id"))
        ids.merge(time_dependent_subscriptions(organization).pluck("subscriptions.id"))
        ids.merge(recurring_rollover_subscriptions(organization).pluck("subscriptions.id"))

        # Drop subscriptions already computed for yesterday. Subtracting here runs the dedup query
        # once per organization, instead of three times (once per leg) if it lived in base_scope.
        ids.subtract(already_computed_subscription_ids(organization))

        enqueue(ids)
      end

      result
    end

    private

    attr_reader :timestamp

    # Recompute every day for subscriptions that received an event recently: their usage may have
    # changed. Restricted to customers entering a new day in their timezone.
    def event_subscriptions(organization)
      base_scope(organization)
        .joins(customer: :billing_entity)
        .where(timezone_window_sql, timestamp:)
        .where("last_received_event_on >= :yesterday", yesterday: yesterday)
    end

    # Recompute every day for subscriptions whose usage changes between billing boundaries WITHOUT
    # new events (prorated charges, weighted_sum aggregations), even when no event was received.
    #
    # We resolve the time-dependent plan ids as a subquery and let Postgres hash semi-join, instead
    # of a correlated EXISTS (which is evaluated per row and is catastrophic on plan-per-subscription
    # organizations).
    def time_dependent_subscriptions(organization)
      base_scope(organization)
        .where(plan_id: time_dependent_plan_ids(organization))
        .joins(customer: :billing_entity)
        .where(timezone_window_sql, timestamp:)
        .where("last_received_event_on IS NULL OR last_received_event_on < :yesterday", yesterday: yesterday)
    end

    # Recurring metrics are constant between events, so they only need to be recomputed once per
    # period, to capture the carried-over value of the new period.
    #
    # `ComputeService` skips the billing day itself (its usage comes from the periodic invoice), so
    # the carry-over row (usage_date = period start) is created on the run of the *next* day. We
    # therefore select subscriptions whose period rolled over yesterday (`timestamp - 1.day`).
    def recurring_rollover_subscriptions(organization)
      scope = base_scope(organization)
        .where(plan_id: recurring_plan_ids(organization))
        .where("last_received_event_on IS NULL OR last_received_event_on < :yesterday", yesterday: yesterday)

      Subscriptions::BillingDateQuery.call(subscriptions: scope, timestamp: timestamp - 1.day)
        .subscriptions
        .where(timezone_window_sql, timestamp:)
    end

    def base_scope(organization)
      Subscription.where(organization_id: organization.id)
        .active
        .where(skip_daily_usage: false)
    end

    # Plans with a charge whose usage changes daily without events: prorated charges or weighted_sum
    # aggregations. Returned as a relation so it composes as a subquery (semi-join).
    #
    # NOTE: fixed charges are intentionally excluded — `CustomerUsageService` only computes usage
    # charges, so a prorated fixed charge does not change the daily usage value.
    def time_dependent_plan_ids(organization)
      Charge.joins(:plan, :billable_metric)
        .where(plans: {organization_id: organization.id})
        .where(charges: {deleted_at: nil}, billable_metrics: {deleted_at: nil})
        .where(
          "charges.prorated = TRUE OR billable_metrics.aggregation_type = ?",
          BillableMetric.aggregation_types[:weighted_sum_agg]
        )
        .select("charges.plan_id")
    end

    # Plans with a recurring billable metric. Returned as a relation so it composes as a subquery.
    def recurring_plan_ids(organization)
      Charge.joins(:plan, :billable_metric)
        .where(plans: {organization_id: organization.id})
        .where(charges: {deleted_at: nil}, billable_metrics: {deleted_at: nil, recurring: true})
        .select("charges.plan_id")
    end

    # Load the matched subscriptions by primary key (cheap, indexed) and enqueue, in bounded slices
    # so we never hold more than ENQUEUE_BATCH_SIZE records in memory at once.
    def enqueue(ids)
      ids.each_slice(ENQUEUE_BATCH_SIZE) do |batch|
        # rubocop:disable Rails/FindEach -- each_slice already bounds the batch to ENQUEUE_BATCH_SIZE;
        # find_each would add redundant keyset batching on top of an already-small `id IN (...)` query.
        Subscription.where(id: batch).each do |subscription|
          schedule_daily_usage(subscription)
        end
        # rubocop:enable Rails/FindEach
      end
    end

    # Subscriptions that already have a daily usage for yesterday (in the customer's timezone).
    # Pre-filters on the indexed raw usage_date before the timezone-aware match, to avoid scanning
    # the org's whole history.
    def already_computed_subscription_ids(organization)
      DailyUsage
        .usage_date_in_timezone(timestamp.to_date - 1.day)
        .where(organization_id: organization.id)
        .where(usage_date: (timestamp.to_date - 2.days)..timestamp.to_date)
        .pluck(:subscription_id)
    end

    def schedule_daily_usage(subscription)
      DailyUsages::ComputeJob.set(wait: job_wait_time).perform_later(subscription, timestamp:)
    end

    def yesterday
      @yesterday ||= timestamp.to_date - 1.day
    end

    # Only schedule customers entering a new day in their timezone; the hourly clock catches each
    # timezone as it crosses midnight.
    def timezone_window_sql
      "DATE_PART('hour', (:timestamp#{at_time_zone})) IN (0, 1, 2)"
    end

    def job_wait_time
      # Randomize job wait time to distribute load across the system. This prevents a thundering
      # herd, and interleaves jobs from different organizations (subscriptions within an org usually
      # share a load profile).
      rand(scheduling_interval)
    end

    def scheduling_interval
      @scheduling_interval ||= begin
        raw_value = ENV["LAGO_DAILY_USAGE_SCHEDULING_JITTER_SECONDS"]
        parsed = Integer(raw_value, exception: false) if raw_value
        parsed = nil if parsed && parsed <= 0
        (parsed || 30.minutes).to_i
      end
    end
  end
end
