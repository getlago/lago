# frozen_string_literal: true

class SubscriptionsQuery < BaseQuery
  Result = BaseResult[:subscriptions]
  Filters = BaseFilters[
    :external_id,
    :external_customer_id,
    :plan_code,
    :status,
    :customer,
    :overriden, # overriden is a legacy typo kept for backward compatibility
    :overridden,
    :exclude_next_subscriptions,
    :currency,
    :billing_entity_ids
  ]

  def call
    subscriptions = base_scope
    # FE pulls next_subscription through Graphql object, which creates additional cases to handle when
    # next_subscription should be excluded from the result to avoid duplicates.
    subscriptions = with_excluded_next_subscriptions(subscriptions) if filters.exclude_next_subscriptions
    subscriptions = subscriptions.where(status: filtered_statuses) if valid_status?
    subscriptions = apply_consistent_ordering(
      subscriptions,
      default_order: <<~SQL.squish
        subscriptions.subscription_at DESC NULLS LAST,
        subscriptions.created_at DESC
      SQL
    )

    subscriptions = with_billing_entity_ids(subscriptions) if filters.billing_entity_ids.present?
    subscriptions = with_external_id(subscriptions) if filters.external_id
    subscriptions = with_external_customer(subscriptions) if filters.external_customer_id
    subscriptions = with_plan_code(subscriptions) if filters.plan_code
    subscriptions = with_overridden(subscriptions) unless overridden_filter.nil?
    subscriptions = with_currency(subscriptions) if filters.currency

    subscriptions = paginate(subscriptions)

    result.subscriptions = subscriptions
    result
  end

  def base_scope
    scope = if organization.present?
      Subscription.where(organization:)
    else
      Subscription.where(customer: filters.customer)
    end.includes(:customer, :plan)

    scope = scope.where(id: matching_ids_by_search) if search_term.present? && filters.external_id.blank?
    scope
  end

  # Free-text search is expressed as a UNION of single-table branches (rather than a cross-table
  # ransack OR) so each branch can use its own trigram index instead of forcing a sequential scan.
  def matching_ids_by_search
    escaped_term = "%#{Subscription.sanitize_sql_like(search_term)}%"
    search_base = Subscription.where(organization:)

    branches = [
      search_base.where("subscriptions.name ILIKE ?", escaped_term).select(:id),
      search_base.where("subscriptions.external_id ILIKE ?", escaped_term).select(:id),
      search_base.where(plan_id: matching_plan_ids).select(:id)
    ]

    branches << search_base.where(id: search_term).select(:id) if search_term.match?(BaseQuery::UUID_REGEX)
    branches << search_base.where(customer_id: matching_customer_ids).select(:id) if search_customers?

    union_sql = branches.map(&:to_sql).join(" UNION ")
    Subscription.unscoped.from("(#{union_sql}) AS subscriptions").select(:id)
  end

  # Columns of a single table are combined with OR (not UNION): Postgres can still hit each column's
  # trigram index through a bitmap OR. Only the cross-table search in #matching_ids_by_search needs a
  # UNION, since an OR spanning several tables would require joins that defeat those indexes.
  def matching_plan_ids
    escaped_term = "%#{Plan.sanitize_sql_like(search_term)}%"

    Plan.where(organization:)
      .where("plans.name ILIKE :term OR plans.code ILIKE :term", term: escaped_term)
      .select(:id)
  end

  def matching_customer_ids
    escaped_term = "%#{Customer.sanitize_sql_like(search_term)}%"

    Customer.where(organization:)
      .where(
        "customers.name ILIKE :term OR customers.firstname ILIKE :term " \
        "OR customers.lastname ILIKE :term OR customers.external_id ILIKE :term " \
        "OR customers.email ILIKE :term",
        term: escaped_term
      )
      .select(:id)
  end

  def search_customers?
    filters.external_customer_id.blank?
  end

  def with_external_id(scope)
    scope.where(external_id: filters.external_id)
  end

  def with_external_customer(scope)
    customers = Customer.where(external_id: filters.external_customer_id)
    scope.where(customer_id: customers.select(:id))
  end

  def with_plan_code(scope)
    scope.joins(:plan).where(plans: {code: filters.plan_code})
  end

  def overridden_filter
    @overridden_filter ||= filters.overridden.nil? ? filters.overriden : filters.overridden
  end

  def with_overridden(scope)
    if ActiveModel::Type::Boolean.new.cast(overridden_filter)
      scope.joins(:plan).where.not(plans: {parent_id: nil})
    else
      scope.joins(:plan).where(plans: {parent_id: nil})
    end
  end

  def with_currency(scope)
    scope.joins(:plan).where(plans: {amount_currency: filters.currency})
  end

  def with_billing_entity_ids(scope)
    scope.joins(:customer).where(
      "subscriptions.billing_entity_id IN (?) OR " \
      "(subscriptions.billing_entity_id IS NULL AND customers.billing_entity_id IN (?))",
      filters.billing_entity_ids,
      filters.billing_entity_ids
    )
  end

  def with_excluded_next_subscriptions(scope)
    # If there is a status filter and statuses of previous subscription and next subscritpion do not match,
    # previous subscription can be filtered out, while next subscription should be included.
    prev_sub_excluded_next_included_in_statuses_clause = ""
    if filters.status.present?
      status_values = filters.status.map { |s| Subscription.statuses[s] }
      prev_sub_excluded_next_included_in_statuses_clause = "OR prev_subscriptions.status NOT IN (#{status_values.join(",")}) AND subscriptions.status IN (#{status_values.join(",")})"
    end
    # FE does not show next sub for terminated subscriptions, so we need to include them in the query.
    prev_sub_terminated_clause = "OR prev_subscriptions.status = #{Subscription.statuses[:terminated]}"
    # FE does not show next canceled subscription, so it should be included
    next_sub_canceled_clause = "OR subscriptions.status = #{Subscription.statuses[:canceled]}"

    scope.joins("LEFT JOIN subscriptions AS prev_subscriptions ON subscriptions.previous_subscription_id = prev_subscriptions.id")
      .where("subscriptions.previous_subscription_id IS NULL #{prev_sub_terminated_clause} #{prev_sub_excluded_next_included_in_statuses_clause} #{next_sub_canceled_clause}")
  end

  def filtered_statuses
    filters.status
  end

  def valid_status?
    filters.status.present? && filters.status.all? { |s| Subscription.statuses.key?(s) }
  end
end
