# frozen_string_literal: true

class EventsQuery < BaseQuery
  Result = BaseResult[:events, :event_model]
  Filters = BaseFilters[
    :code,
    :external_subscription_id,
    :timestamp_from_started_at,
    :timestamp_from,
    :timestamp_to,
    :enriched
  ]

  def call
    return result unless validate_filters.success?

    events = event_model
    events = events.where(organization_id: organization.id)
    events = paginate(events)

    events = if pg_event?
      events.order(timestamp: :desc, transaction_id: :asc)
    elsif ch_event_raw?
      events.order(ingested_at: :desc, transaction_id: :asc)
    elsif ch_event_enriched?
      events.order(enriched_at: :desc, transaction_id: :asc)
    end

    events = with_code(events) if filters.code
    events = with_external_subscription_id(events) if filters.external_subscription_id
    events = with_timestamp_range(events)

    result.event_model = event_model.to_s
    result.events = events
    result
  rescue BaseService::FailedResult
    result
  end

  private

  def filters_contract
    @filters_contract ||= Queries::EventsQueryFiltersContract.new
  end

  def event_model
    if pg_event?
      Event
    elsif ch_event_raw?
      Clickhouse::EventsRaw
    elsif ch_event_enriched?
      Clickhouse::EventsEnriched
    end
  end

  def with_code(scope)
    scope.where(code: filters.code)
  end

  def with_external_subscription_id(scope)
    scope.where(external_subscription_id: filters.external_subscription_id)
  end

  def with_timestamp_range(scope)
    if timestamp_from_started_at? && subscription
      scope = scope.where(timestamp: subscription.started_at..)
    elsif filters.timestamp_from
      scope = scope.where(timestamp: timestamp_from..)
    end

    scope = scope.where(timestamp: ..timestamp_to) if filters.timestamp_to

    scope
  end

  def subscription
    @subscription ||= organization.subscriptions
      .order("terminated_at DESC NULLS FIRST, started_at DESC")
      .find_by(
        external_id: filters.external_subscription_id
      )
  end

  def timestamp_from
    @timestamp_from ||= parse_datetime_filter(:timestamp_from)
  end

  def timestamp_to
    @timestamp_to ||= parse_datetime_filter(:timestamp_to)
  end

  def timestamp_from_started_at?
    ActiveModel::Type::Boolean.new.cast(filters.timestamp_from_started_at)
  end

  def pg_event?
    !organization.clickhouse_events_store?
  end

  def ch_event_raw?
    organization.clickhouse_events_store? && !filters.enriched
  end

  def ch_event_enriched?
    organization.clickhouse_events_store? && filters.enriched
  end
end
