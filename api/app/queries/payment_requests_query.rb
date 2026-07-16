# frozen_string_literal: true

class PaymentRequestsQuery < BaseQuery
  Result = BaseResult[:payment_requests]
  Filters = BaseFilters[:external_customer_id, :payment_status, :currency, :billing_entity_ids]

  def call
    payment_requests = PaymentRequest.where(organization:)

    payment_requests = with_billing_entity_ids(payment_requests) if filters.billing_entity_ids.present?
    payment_requests = with_external_customer(payment_requests) if filters.external_customer_id
    payment_requests = with_payment_status(payment_requests) if filters.payment_status
    payment_requests = with_currency(payment_requests) if filters.currency

    payment_requests = apply_consistent_ordering(payment_requests)
    payment_requests = paginate(payment_requests)
    result.payment_requests = payment_requests
    result
  end

  private

  def with_billing_entity_ids(scope)
    scope.where(
      id: PaymentRequest.joins(:invoices)
        .where(invoices: {billing_entity_id: filters.billing_entity_ids})
        .select(:id)
    )
  end

  def with_external_customer(scope)
    scope.joins(:customer).where(customers: {external_id: filters.external_customer_id})
  end

  def with_payment_status(scope)
    scope.where(payment_status: filters.payment_status)
  end

  def with_currency(scope)
    scope.where(amount_currency: filters.currency)
  end
end
