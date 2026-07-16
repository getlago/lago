# frozen_string_literal: true

class QuotesQuery < BaseQuery
  Result = BaseResult[:quotes]
  Filters = BaseFilters[:customers, :external_customer_ids, :numbers, :statuses, :from_date, :to_date, :owners, :order_types]

  def call
    return result unless validate_filters.success?

    quotes = base_scope
    quotes = with_customer(quotes) if filters.customers.present?
    quotes = with_external_customers(quotes) if filters.external_customer_ids.present?
    quotes = with_number(quotes) if filters.numbers.present?
    quotes = with_status(quotes) if filters.statuses.present?
    quotes = with_date(quotes) if filters.from_date.present? || filters.to_date.present?
    quotes = with_owners(quotes) if filters.owners.present?
    quotes = with_order_types(quotes) if filters.order_types.present?

    # final ordering and pagination
    quotes = quotes.order(created_at: :desc)
    quotes = paginate(quotes)

    result.quotes = quotes
    result
  rescue BaseService::FailedResult
    result
  end

  private

  def filters_contract
    @filters_contract ||= Queries::QuotesQueryFiltersContract.new
  end

  def base_scope
    Quote.where(organization:)
  end

  def with_customer(scope)
    scope.where(customer_id: filters.customers)
  end

  def with_external_customers(scope)
    scope.joins(:customer).where(customers: {external_id: filters.external_customer_ids})
  end

  def with_number(scope)
    scope.where(number: filters.numbers)
  end

  def with_status(scope)
    # check status of the current (latest) version
    quote_ids = QuoteVersion
      .where(
        organization:,
        status: filters.statuses
      )
      .where("sequential_id = (SELECT MAX(sequential_id) FROM quote_versions qv WHERE qv.quote_id = quote_versions.quote_id)")
      .select(:quote_id)

    scope.where(id: quote_ids)
  end

  def with_date(scope)
    scope.where(created_at: filters.from_date..filters.to_date)
  end

  def with_owners(scope)
    quote_ids = QuoteOwner
      .where(
        organization:,
        user_id: filters.owners
      )
      .select(:quote_id)
      .distinct

    scope.where(id: quote_ids)
  end

  def with_order_types(scope)
    scope.where(order_type: filters.order_types)
  end
end
