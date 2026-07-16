# frozen_string_literal: true

class ActivityLogsQuery < BaseQuery
  Result = BaseResult[:activity_logs]
  Filters = BaseFilters[
    :from_date,
    :to_date,
    :api_key_ids,
    :activity_ids,
    :activity_types,
    :activity_sources,
    :user_emails,
    :external_customer_id,
    :external_subscription_id,
    :resource_ids,
    :resource_types
  ]

  def call
    return result.forbidden_failure! unless Utils::ActivityLog.available?

    activity_logs = Clickhouse::ActivityLog.where(organization_id: organization.id)
    activity_logs = paginate(activity_logs)
    activity_logs = activity_logs.order(logged_at: :desc)

    activity_logs = within_retention_period(activity_logs) if organization.audit_logs_period.present?
    activity_logs = with_logged_at_range(activity_logs) if filters.from_date || filters.to_date
    activity_logs = with_api_key_ids(activity_logs) if filters.api_key_ids.present?
    activity_logs = with_activity_ids(activity_logs) if filters.activity_ids.present?
    activity_logs = with_activity_types(activity_logs) if filters.activity_types.present?
    activity_logs = with_activity_sources(activity_logs) if filters.activity_sources.present?
    activity_logs = with_user_emails(activity_logs) if filters.user_emails.present?
    activity_logs = with_external_customer_id(activity_logs) if filters.external_customer_id.present?
    activity_logs = with_external_subscription_id(activity_logs) if filters.external_subscription_id.present?
    activity_logs = with_resource_ids(activity_logs) if filters.resource_ids.present?
    activity_logs = with_resource_types(activity_logs) if filters.resource_types.present?

    result.activity_logs = activity_logs
    result
  end

  private

  def within_retention_period(scope)
    period = organization.audit_logs_period.days
    scope.where(logged_at: period.ago..)
  end

  def with_logged_at_range(scope)
    scope = scope.where(logged_at: from_date..) if filters.from_date
    scope = scope.where(logged_at: ..to_date) if filters.to_date
    scope
  end

  def with_api_key_ids(scope)
    scope.where(api_key_id: filters.api_key_ids)
  end

  def with_activity_ids(scope)
    scope.where(activity_id: filters.activity_ids)
  end

  def with_activity_types(scope)
    scope.where(activity_type: filters.activity_types)
  end

  def with_activity_sources(scope)
    scope.where(activity_source: filters.activity_sources)
  end

  def with_user_emails(scope)
    user_ids = organization.users.where(email: filters.user_emails).pluck(:id)
    scope.where(user_id: user_ids)
  end

  def with_external_customer_id(scope)
    scope.where(external_customer_id: filters.external_customer_id)
  end

  def with_external_subscription_id(scope)
    scope.where(external_subscription_id: filters.external_subscription_id)
  end

  def with_resource_ids(scope)
    scope.where(resource_id: filters.resource_ids)
  end

  def with_resource_types(scope)
    scope.where(resource_type: filters.resource_types)
  end

  def from_date
    @from_date ||= parse_datetime_filter(:from_date)
  end

  def to_date
    @to_date ||= parse_datetime_filter(:to_date)
  end
end
