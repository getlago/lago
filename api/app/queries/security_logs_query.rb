# frozen_string_literal: true

class SecurityLogsQuery < BaseQuery
  Result = BaseResult[:security_logs]
  Filters = BaseFilters[
    :from_date,
    :to_date,
    :api_key_ids,
    :user_ids,
    :log_types,
    :log_events
  ]

  def call
    return result.forbidden_failure! unless self.class.available?
    return result.forbidden_failure! unless organization.security_logs_enabled?
    return result.single_validation_failure!(field: :to_date, error_code: "value_is_mandatory") if filters.to_date.blank?

    security_logs = Clickhouse::SecurityLog.where(organization_id: organization.id)
    security_logs = paginate(security_logs)
    security_logs = security_logs.order(logged_at: :desc)

    security_logs = with_logged_at_range(security_logs) if filters.from_date || filters.to_date
    security_logs = with_api_key_ids(security_logs) if filters.api_key_ids.present?
    security_logs = with_user_ids(security_logs) if filters.user_ids.present?
    security_logs = with_log_types(security_logs) if filters.log_types.present?
    security_logs = with_log_events(security_logs) if filters.log_events.present?

    result.security_logs = security_logs
    result
  end

  def self.available?
    ENV["LAGO_CLICKHOUSE_ENABLED"].present?
  end

  private

  def with_logged_at_range(scope)
    scope = scope.where(logged_at: from_date..) if filters.from_date
    scope = scope.where(logged_at: ..to_date) if filters.to_date
    scope
  end

  def with_api_key_ids(scope)
    scope.where(api_key_id: filters.api_key_ids)
  end

  def with_user_ids(scope)
    scope.where(user_id: filters.user_ids)
  end

  def with_log_types(scope)
    scope.where(log_type: filters.log_types)
  end

  def with_log_events(scope)
    scope.where(log_event: filters.log_events)
  end

  def from_date
    @from_date ||= parse_datetime_filter(:from_date)
  end

  def to_date
    @to_date ||= parse_datetime_filter(:to_date)
  end
end
