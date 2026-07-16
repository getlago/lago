# frozen_string_literal: true

class PaymentsQuery < BaseQuery
  Result = BaseResult[:payments]
  Filters = BaseFilters[:invoice_id, :external_customer_id, :currency]

  def call
    return result unless validate_filters.success?

    payments = base_scope
    payments = apply_filters(payments)
    payments = paginate(payments)
    payments = apply_consistent_ordering(payments)

    result.payments = payments
    result
  end

  private

  def filters_contract
    @filters_contract ||= Queries::PaymentsQueryFiltersContract.new
  end

  def base_scope
    scope = Payment.where.not(customer_id: nil)
      .where(organization:)
      .where.not(payable_id: nil)
      .where(visible_payable_condition)

    return scope if search_term.blank?

    scope.where(id: matching_ids_by_search)
  end

  def matching_ids_by_search
    escaped_term = "%#{Payment.sanitize_sql_like(search_term)}%"
    search_base = Payment.where(organization:)

    branches = [
      search_base.where("payments.provider_payment_id ILIKE ?", escaped_term).select(:id),
      search_base.where("payments.reference ILIKE ?", escaped_term).select(:id)
    ]

    branches << search_base.where(id: search_term).select(:id) if search_term.match?(BaseQuery::UUID_REGEX)

    if filters.invoice_id.blank?
      branches << search_base.where(payable_type: "Invoice", payable_id: matching_invoice_ids).select(:id)
    end

    if filters.external_customer_id.blank?
      branches << search_base.where(customer_id: matching_customer_ids).select(:id)
    end

    union_sql = branches.map(&:to_sql).join(" UNION ")
    Payment.unscoped.from("(#{union_sql}) AS payments").select(:id)
  end

  def matching_invoice_ids
    escaped_term = "%#{Invoice.sanitize_sql_like(search_term)}%"
    organization.invoices.where("invoices.number ILIKE ?", escaped_term).select(:id)
  end

  def matching_customer_ids
    escaped_term = "%#{Customer.sanitize_sql_like(search_term)}%"

    branches = %i[name firstname lastname external_id email].map do |field|
      organization.customers.where("customers.#{field} ILIKE ?", escaped_term).select(:id)
    end

    union_sql = branches.map(&:to_sql).join(" UNION ")
    Customer.unscoped.from("(#{union_sql}) AS customers").select(:id)
  end

  def visible_payable_condition
    ActiveRecord::Base.sanitize_sql_array([
      <<~SQL.squish,
        CASE payments.payable_type
          WHEN 'Invoice' THEN EXISTS(
            SELECT 1 FROM invoices
            WHERE invoices.id = payments.payable_id
            AND invoices.status IN (:visible_statuses)
            AND organization_id = :organization_id
          )
          ELSE TRUE
        END
      SQL
      {
        visible_statuses: Invoice::VISIBLE_STATUS.values,
        organization_id: organization.id
      }
    ])
  end

  def apply_filters(scope)
    scope = filter_by_invoice(scope) if filters.invoice_id.present?
    scope = filter_by_customer(scope) if filters.external_customer_id.present?
    scope = filter_by_currency(scope) if filters.currency.present?
    scope
  end

  def filter_by_customer(scope)
    external_customer_id = filters.external_customer_id

    scope.joins(:customer).where("customers.external_id = :external_customer_id", external_customer_id:)
  end

  def filter_by_invoice(scope)
    invoice_id = filters.invoice_id

    scope.joins(<<~SQL.squish)
      LEFT JOIN invoices_payment_requests
        ON invoices_payment_requests.payment_request_id = payments.payable_id
        AND payments.payable_type = 'PaymentRequest'
    SQL
      .where(
        "(payments.payable_type = 'Invoice' AND payments.payable_id = :invoice_id) " \
        "OR invoices_payment_requests.invoice_id = :invoice_id",
        invoice_id:
      )
  end

  def filter_by_currency(scope)
    scope.where(amount_currency: filters.currency)
  end
end
