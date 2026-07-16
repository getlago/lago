# frozen_string_literal: true

class WebhooksQuery < BaseQuery
  Result = BaseResult[:webhooks]
  Filters = BaseFilters[:webhook_endpoint_id, :statuses, :event_types, :http_statuses, :from_date, :to_date]

  def call
    return result unless validate_filters.success?

    webhooks = base_scope.result
    webhooks = paginate(webhooks)
    webhooks = webhooks.order({updated_at: :desc, created_at: :desc})

    webhooks = with_statuses(webhooks) if filters.statuses.present?
    webhooks = with_event_types(webhooks) if filters.event_types.present?
    webhooks = with_from_date(webhooks) if filters.from_date.present?
    webhooks = with_to_date(webhooks) if filters.to_date.present?
    webhooks = with_http_statuses(webhooks) if filters.http_statuses.present?

    result.webhooks = webhooks
    result
  rescue BaseService::FailedResult
    result
  end

  private

  def filters_contract
    @filters_contract ||= Queries::WebhooksQueryFiltersContract.new
  end

  def base_scope
    Webhook.where(organization:, webhook_endpoint_id: filters.webhook_endpoint_id).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {
      m: "or",
      id_cont: search_term,
      object_id_cont: search_term
    }
  end

  def with_statuses(scope)
    scope.where(status: filters.statuses)
  end

  def with_event_types(scope)
    scope.where(webhook_type: filters.event_types)
  end

  def with_from_date(scope)
    scope.where(updated_at: filters.from_date..)
  end

  def with_to_date(scope)
    scope.where(updated_at: ..filters.to_date)
  end

  def with_http_statuses(scope)
    statuses = filters.http_statuses.map(&:to_s).map(&:downcase)
    ranges = get_http_status_ranges(statuses)

    conditions = []
    ranges.each do |range|
      conditions << scope.where(http_status: range)
    end
    if statuses.include?("timeout")
      conditions << scope.where(http_status: nil, status: :failed)
    end

    return scope if conditions.empty?

    conditions.reduce { |rel, cond| rel.or(cond) }
  end

  def get_http_status_ranges(statuses)
    statuses.map do |status|
      case status
      when /\A\d{3}\z/ # exact status like 200, 404
        base = status.to_i
        base..base
      when /\A(\d)xx\z/i # wildcard like 2xx, 4xx
        base = $1.to_i * 100
        base..(base + 99)
      when /\A(\d{3})\s*-\s*(\d{3})\z/ # range like "404-412"
        $1.to_i..$2.to_i
      end
    end.compact
  end
end
