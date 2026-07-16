# frozen_string_literal: true

module Events
  class DeleteForMetricService < BaseService
    Result = BaseResult

    def initialize(billable_metric:)
      @billable_metric = billable_metric
      @deleted_at = billable_metric.deleted_at
      super
    end

    def call
      return result unless billable_metric.discarded?

      clickhouse_enabled = ENV["LAGO_CLICKHOUSE_ENABLED"].present?

      # The subscription is queried in batches to avoid memory pressure
      # and cross-database subqueries: events is built to live on a dedicated
      # database (so is clickhouse) while subscriptions/charges live on the primary database.
      subscriptions_relation.in_batches(of: BATCH_SIZE) do |batch|
        rows = batch.pluck(:id, :external_id)
        next if rows.empty?

        subscription_ids, external_subscription_ids = rows.transpose

        delete_postgres_events(subscription_ids, external_subscription_ids)
        delete_clickhouse_events(external_subscription_ids) if clickhouse_enabled
        expire_charge_caches(subscription_ids)
      end

      result
    end

    private

    BATCH_SIZE = 10_000
    CLICKHOUSE_BATCH_SIZE = BATCH_SIZE / 2
    CLICKHOUSE_TABLES = {
      events_raw: :ingested_at,
      events_enriched: :enriched_at,
      events_enriched_expanded: :enriched_at
    }.freeze
    CLICKHOUSE_MUTATIONS_SYNC = "0" # Async

    attr_reader :billable_metric, :deleted_at

    delegate :code, :organization_id, to: :billable_metric

    def subscriptions_relation
      # Explicit SQL join bypasses Charge's `default_scope -> { kept }` so
      # discarded charges are still considered when collecting subscriptions.
      Subscription
        .joins(:plan)
        .joins("INNER JOIN charges ON charges.plan_id = plans.id")
        .where("charges.billable_metric_id = ?", billable_metric.id)
        .distinct
    end

    def delete_postgres_events(subscription_ids, external_subscription_ids)
      # Delete events having an old-style `subscription_id`
      Event.where(
        organization_id: organization_id,
        code: code,
        subscription_id: subscription_ids
      ).where("events.created_at <= ?", deleted_at)
        .in_batches.update_all(deleted_at:) # rubocop:disable Rails/SkipsModelValidations

      # Delete events using the new `external_subscription_id`
      Event.where(
        organization_id: organization_id,
        code: code,
        external_subscription_id: external_subscription_ids
      ).where("events.created_at <= ?", deleted_at)
        .in_batches.update_all(deleted_at:) # rubocop:disable Rails/SkipsModelValidations
    end

    # Delete clickhouse events using async mutations to avoid blocking or
    # timeouts when the metric is attached to a large number of events.
    # The id list is sliced into clickhouse_batch_size chunks before being
    # inlined into the ALTER TABLE … DELETE statement so each query stays
    # under ClickHouse's max_query_size (default 256 KiB).
    def delete_clickhouse_events(external_subscription_ids)
      external_subscription_ids.each_slice(CLICKHOUSE_BATCH_SIZE) do |slice|
        CLICKHOUSE_TABLES.each do |table, date_field|
          async_delete_clickhouse(table, date_field, slice)
        end
      end
    end

    def expire_charge_caches(subscription_ids)
      Subscriptions::ChargeCacheService.expire_for_subscriptions(subscription_ids)
    end

    def async_delete_clickhouse(table, date_field, external_subscription_ids)
      sql = ::Clickhouse::BaseRecord.sanitize_sql_array([
        "ALTER TABLE #{table} DELETE " \
          "WHERE organization_id = ? AND code = ? " \
          "AND external_subscription_id IN (?) AND #{date_field} <= ? " \
          "SETTINGS mutations_sync = #{CLICKHOUSE_MUTATIONS_SYNC}",
        organization_id,
        code,
        external_subscription_ids,
        deleted_at
      ])

      ::Clickhouse::BaseRecord.connection.execute(sql)
    end
  end
end
