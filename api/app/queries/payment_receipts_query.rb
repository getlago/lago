# frozen_string_literal: true

class PaymentReceiptsQuery < BaseQuery
  Result = BaseResult[:payment_receipts]
  Filters = BaseFilters[:invoice_id]

  def call
    return result unless validate_filters.success?

    payment_receipts = apply_filters(base_scope)
    payment_receipts = paginate(payment_receipts)
    payment_receipts = apply_consistent_ordering(payment_receipts)

    result.payment_receipts = payment_receipts
    result
  end

  private

  def filters_contract
    @filters_contract ||= Queries::PaymentReceiptsQueryFiltersContract.new
  end

  def base_scope
    PaymentReceipt.where(organization:)
  end

  def apply_filters(scope)
    scope = filter_by_invoice(scope) if filters.invoice_id.present?
    scope
  end

  def filter_by_invoice(scope)
    invoice_id = filters.invoice_id

    joins = ActiveRecord::Base.sanitize_sql_array([
      <<~SQL,
        INNER JOIN payments ON payments.id = payment_receipts.payment_id
        LEFT JOIN invoices ON invoices.id = payments.payable_id AND payments.payable_type = 'Invoice'
        LEFT JOIN payment_requests
            ON payment_requests.id = payments.payable_id
            AND payments.payable_type = 'PaymentRequest'
            AND payment_requests.organization_id = ?
        LEFT JOIN invoices_payment_requests ON invoices_payment_requests.payment_request_id = payment_requests.id
      SQL
      organization.id
    ])

    scope.joins(joins)
      .where("invoices.id = :invoice_id OR invoices_payment_requests.invoice_id = :invoice_id", invoice_id:)
  end
end
