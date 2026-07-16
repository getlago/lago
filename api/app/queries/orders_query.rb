# frozen_string_literal: true

class OrdersQuery < BaseQuery
  Result = BaseResult[:orders]
  Filters = BaseFilters[
    :status,
    :order_type,
    :execution_mode,
    :customer_id,
    :number,
    :order_form_number,
    :quote_number,
    :owner_id,
    :executed_at_from,
    :executed_at_to
  ]

  def call
    return result unless validate_filters.success?

    orders = base_scope.result
    orders = with_status(orders) if filters.status.present?
    orders = with_order_type(orders) if filters.order_type.present?
    orders = with_execution_mode(orders) if filters.execution_mode.present?
    orders = with_customer_id(orders) if filters.customer_id.present?
    orders = with_number(orders) if filters.number.present?
    orders = with_order_form_number(orders) if filters.order_form_number.present?
    orders = with_quote_number(orders) if filters.quote_number.present?
    orders = with_owner_id(orders) if filters.owner_id.present?
    orders = with_executed_at_range(orders) if executed_at_range?
    orders = paginate(orders)
    orders = apply_consistent_ordering(orders)

    result.orders = orders
    result
  end

  private

  def filters_contract
    @filters_contract ||= Queries::OrdersQueryFiltersContract.new
  end

  def base_scope
    organization.orders.preload(order_form: {quote_version: :quote}).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {
      m: "or",
      number_cont: search_term
    }
  end

  def with_status(scope)
    scope.where(status: filters.status)
  end

  def with_order_type(scope)
    scope.joins(order_form: :quote).where(quotes: {order_type: filters.order_type})
  end

  def with_execution_mode(scope)
    scope.where(execution_mode: filters.execution_mode)
  end

  def with_customer_id(scope)
    scope.where(customer_id: filters.customer_id)
  end

  def with_number(scope)
    scope.where(number: filters.number)
  end

  def with_order_form_number(scope)
    scope.joins(:order_form).where(order_forms: {number: filters.order_form_number})
  end

  def with_quote_number(scope)
    scope.joins(order_form: :quote).where(quotes: {number: filters.quote_number})
  end

  def with_owner_id(scope)
    scope.joins(order_form: :quote).where(
      quotes: {id: QuoteOwner.where(user_id: filters.owner_id).select(:quote_id)}
    )
  end

  def with_executed_at_range(scope)
    scope = scope.where(executed_at: executed_at_from..) if filters.executed_at_from
    scope = scope.where(executed_at: ..executed_at_to) if filters.executed_at_to
    scope
  end

  def executed_at_range?
    filters.executed_at_from.present? || filters.executed_at_to.present?
  end

  def executed_at_from
    @executed_at_from ||= parse_datetime_filter(:executed_at_from)
  end

  def executed_at_to
    @executed_at_to ||= parse_datetime_filter(:executed_at_to)
  end
end
