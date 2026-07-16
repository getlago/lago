# frozen_string_literal: true

class OrderFormsQuery < BaseQuery
  Result = BaseResult[:order_forms]
  Filters = BaseFilters[
    :status,
    :customer_id,
    :number,
    :quote_number,
    :owner_id,
    :created_at_from,
    :created_at_to,
    :expires_at_from,
    :expires_at_to
  ]

  def call
    return result unless validate_filters.success?

    order_forms = base_scope.result
    order_forms = with_status(order_forms) if filters.status.present?
    order_forms = with_customer_id(order_forms) if filters.customer_id.present?
    order_forms = with_number(order_forms) if filters.number.present?
    order_forms = with_quote_number(order_forms) if filters.quote_number.present?
    order_forms = with_owner_id(order_forms) if filters.owner_id.present?
    order_forms = with_created_at_range(order_forms) if created_at_range?
    order_forms = with_expires_at_range(order_forms) if expires_at_range?
    order_forms = paginate(order_forms)
    order_forms = apply_consistent_ordering(order_forms)

    result.order_forms = order_forms
    result
  rescue BaseService::FailedResult
    result
  end

  private

  def filters_contract
    @filters_contract ||= Queries::OrderFormsQueryFiltersContract.new
  end

  def base_scope
    organization.order_forms.includes(:quote_version).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {number_cont: search_term}
  end

  def with_status(scope)
    scope.where(status: filters.status)
  end

  def with_customer_id(scope)
    scope.where(customer_id: filters.customer_id)
  end

  def with_number(scope)
    scope.where(number: filters.number)
  end

  def with_quote_number(scope)
    scope.joins(quote_version: :quote).where(quotes: {number: filters.quote_number})
  end

  def with_owner_id(scope)
    scope.where(
      quote_version_id: QuoteVersion.where(
        quote_id: QuoteOwner.where(user_id: filters.owner_id).select(:quote_id)
      ).select(:id)
    )
  end

  def with_created_at_range(scope)
    scope = scope.where(created_at: created_at_from..) if filters.created_at_from
    scope = scope.where(created_at: ..created_at_to) if filters.created_at_to
    scope
  end

  def with_expires_at_range(scope)
    scope = scope.where(expires_at: expires_at_from..) if filters.expires_at_from
    scope = scope.where(expires_at: ..expires_at_to) if filters.expires_at_to
    scope
  end

  def created_at_range?
    filters.created_at_from.present? || filters.created_at_to.present?
  end

  def expires_at_range?
    filters.expires_at_from.present? || filters.expires_at_to.present?
  end

  def created_at_from
    @created_at_from ||= parse_datetime_filter(:created_at_from)
  end

  def created_at_to
    @created_at_to ||= parse_datetime_filter(:created_at_to)
  end

  def expires_at_from
    @expires_at_from ||= parse_datetime_filter(:expires_at_from)
  end

  def expires_at_to
    @expires_at_to ||= parse_datetime_filter(:expires_at_to)
  end
end
