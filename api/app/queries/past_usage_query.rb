# frozen_string_literal: true

class PastUsageQuery < BaseQuery
  Result = BaseResult[:usage_periods, :current_page, :next_page, :prev_page, :total_pages, :total_count]
  Filters = BaseFilters[:external_customer_id, :external_subscription_id, :periods_count, :billable_metric_code]

  UsagePeriods = Data.define(:invoice_subscription, :fees)

  def call
    validate_filters
    return result if result.error.present?

    query_result = apply_consistent_ordering(query)
    result.usage_periods = query_result.map do |invoice_subscription|
      UsagePeriods.new(
        invoice_subscription:,
        fees: fees_query(invoice_subscription.invoice)
      )
    end

    # NOTE: Pagination attributes
    if pagination
      result.current_page = query_result.current_page
      result.next_page = query_result.next_page
      result.prev_page = query_result.prev_page
      result.total_pages = query_result.total_pages
      result.total_count = query_result.total_count
    end

    result
  end

  private

  def query
    base_query = InvoiceSubscription.joins(subscription: :customer)
      .where.not(charges_from_datetime: nil)
      .where(customers: {external_id: filters.external_customer_id, organization_id: organization.id})
      .where(subscriptions: {external_id: filters.external_subscription_id})
      .order(charges_from_datetime: :desc)
      .includes(:invoice)

    base_query = paginate(base_query)
    base_query = base_query.limit(filters.periods_count.to_i) if filters.periods_count
    base_query
  end

  def fees_query(invoice)
    query = invoice.fees.joins(:subscription).where(subscription: {external_id: filters.external_subscription_id}).charge.includes(:charge_filter, :presentation_breakdowns)
    return query unless filters.billable_metric_code

    query.joins(:charge).where(charges: {billable_metric_id: billable_metric.id})
  end

  def validate_filters
    if filters.external_customer_id.blank?
      return result.single_validation_failure!(
        field: :external_customer_id,
        error_code: "value_is_mandatory"
      )
    end

    if filters.external_subscription_id.blank?
      return result.single_validation_failure!(
        field: :external_subscription_id,
        error_code: "value_is_mandatory"
      )
    end

    return if filters.billable_metric_code.blank?

    result.not_found_failure!(resource: "billable_metric") if billable_metric.blank?
  end

  def billable_metric
    @billable_metric ||= organization.billable_metrics.find_by(code: filters.billable_metric_code)
  end
end
