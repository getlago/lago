# frozen_string_literal: true

class InvoicesQuery < BaseQuery
  Result = BaseResult[:invoices]
  Filters = BaseFilters[
    :billing_entity_ids,
    :currency,
    :customer_external_id,
    :customer_id,
    :invoice_type,
    :issuing_date_from,
    :issuing_date_to,
    :status,
    :payment_status,
    :payment_dispute_lost,
    :payment_overdue,
    :amount_from,
    :amount_to,
    :metadata,
    :partially_paid,
    :positive_due_amount,
    :self_billed,
    :subscription_id,
    :settlements
  ]

  def call
    return result unless validate_filters.success?

    invoices = base_scope.includes(:customer).preload(file_attachment: :blob, xml_file_attachment: :blob)

    invoices = with_billing_entity_ids(invoices) if filters.billing_entity_ids.present?
    invoices = with_currency(invoices) if filters.currency
    invoices = with_customer_external_id(invoices) if filters.customer_external_id
    invoices = with_customer_id(invoices) if filters.customer_id.present?
    invoices = with_invoice_type(invoices) if filters.invoice_type.present?
    invoices = with_issuing_date_range(invoices) if filters.issuing_date_from || filters.issuing_date_to
    invoices = with_status(invoices)
    invoices = with_payment_status(invoices) if filters.payment_status.present?
    invoices = with_payment_dispute_lost(invoices) unless filters.payment_dispute_lost.nil?
    invoices = with_payment_overdue(invoices) unless filters.payment_overdue.nil?
    invoices = with_amount_range(invoices) if filters.amount_from.present? || filters.amount_to.present?
    invoices = with_metadata(invoices) if filters.metadata.present?
    invoices = with_partially_paid(invoices) unless filters.partially_paid.nil?
    invoices = with_positive_due_amount(invoices) unless filters.positive_due_amount.nil?
    invoices = with_self_billed(invoices) unless filters.self_billed.nil?
    invoices = with_subscription_id(invoices) if filters.subscription_id.present?
    invoices = with_settlements(invoices) if valid_settlements.present?

    invoices = paginate(invoices)
    invoices = apply_consistent_ordering(
      invoices,
      default_order: {issuing_date: :desc, created_at: :desc}
    )

    result.invoices = invoices
    result
  rescue BaseService::FailedResult
    result
  end

  private

  def filters_contract
    @filters_contract ||= Queries::InvoicesQueryFiltersContract.new
  end

  def base_scope
    scope = organization.invoices
    return scope if search_term.blank?

    scope = scope.with(matching_customers: matching_customers) if search_customers?
    scope
      .with(matching_invoices: matching_invoices)
      .where("invoices.id IN (SELECT id FROM matching_invoices)")
  end

  def search_customers?
    filters.customer_id.blank? && filters.customer_external_id.blank?
  end

  def matching_customers
    escaped_term = "%#{Customer.sanitize_sql_like(search_term)}%"

    organization.customers
      .where(
        "customers.name ILIKE :term OR customers.firstname ILIKE :term " \
        "OR customers.lastname ILIKE :term OR customers.external_id ILIKE :term " \
        "OR customers.email ILIKE :term",
        term: escaped_term
      )
      .select(:id)
  end

  def matching_invoices
    escaped_term = "%#{Invoice.sanitize_sql_like(search_term)}%"
    search_base = organization.invoices

    branches = [
      search_base.where("invoices.number ILIKE ?", escaped_term).select(:id)
    ]

    branches << search_base.where(id: search_term).select(:id) if search_term.match?(BaseQuery::UUID_REGEX)

    if search_customers?
      branches << search_base.where("invoices.customer_id IN (SELECT id FROM matching_customers)").select(:id)
    end

    union_sql = branches.map(&:to_sql).join(" UNION ")
    Invoice.unscoped.from("(#{union_sql}) AS invoices").select(:id)
  end

  def with_billing_entity_ids(scope)
    scope.where(billing_entity_id: filters.billing_entity_ids)
  end

  def with_currency(scope)
    scope.where(currency: filters.currency)
  end

  def with_customer_external_id(scope)
    scope.joins(:customer).where(customers: {external_id: filters.customer_external_id})
  end

  def with_customer_id(scope)
    scope.where(customer_id: filters.customer_id)
  end

  def with_subscription_id(scope)
    scope.joins(:invoice_subscriptions).where(invoice_subscriptions: {subscription_id: filters.subscription_id})
  end

  def with_invoice_type(scope)
    scope.where(invoice_type: filters.invoice_type)
  end

  def with_status(scope)
    visible_keys = Invoice::VISIBLE_STATUS.keys.map(&:to_s)
    statuses = if filters.status.present?
      Array(filters.status).map(&:to_s) & visible_keys
    else
      visible_keys
    end
    scope.where(status: statuses)
  end

  def with_payment_status(scope)
    scope.where(payment_status: filters.payment_status)
  end

  def with_payment_dispute_lost(scope)
    if filters.payment_dispute_lost
      scope.where.not(payment_dispute_lost_at: nil)
    else
      scope.where(payment_dispute_lost_at: nil)
    end
  end

  def with_payment_overdue(scope)
    scope.where(payment_overdue: filters.payment_overdue)
  end

  def with_positive_due_amount(scope)
    positive_due_amount = ActiveModel::Type::Boolean.new.cast(filters.positive_due_amount)

    if positive_due_amount
      scope.where("total_amount_cents - total_paid_amount_cents > 0")
    else
      scope.where("total_amount_cents - total_paid_amount_cents <= 0")
    end
  end

  def with_partially_paid(scope)
    partially_paid = ActiveModel::Type::Boolean.new.cast(filters.partially_paid)

    if partially_paid
      scope.where("total_amount_cents > total_paid_amount_cents AND total_paid_amount_cents > 0")
    else
      scope.where("total_amount_cents = total_paid_amount_cents OR total_paid_amount_cents = 0")
    end
  end

  def with_issuing_date_range(scope)
    scope = scope.where(issuing_date: issuing_date_from..) if filters.issuing_date_from
    scope = scope.where(issuing_date: ..issuing_date_to) if filters.issuing_date_to
    scope
  end

  def with_amount_range(scope)
    scope = scope.where("invoices.total_amount_cents >= ?::numeric", filters.amount_from) if filters.amount_from
    scope = scope.where("invoices.total_amount_cents <= ?::numeric", filters.amount_to) if filters.amount_to
    scope
  end

  def with_metadata(scope)
    base_scope = scope.left_joins(:metadata).limit(nil).offset(nil)
    subquery = base_scope

    presence_filters = filters.metadata.select { |_k, v| v.present? }
    absence_filters = filters.metadata.select { |_k, v| v.blank? }

    presence_filters.each_with_index do |(key, value), index|
      subquery = if index.zero?
        subquery.where(metadata: {key:, value:})
      else
        subquery.or(base_scope.where(metadata: {key:, value:}))
      end
    end

    if presence_filters.any?
      subquery = subquery
        .group("invoices.id")
        .having("COUNT(DISTINCT metadata.key) = ?", presence_filters.size)
    end

    if absence_filters.any?
      subquery = subquery.where.not(
        id: base_scope.where(metadata: {key: absence_filters.keys}).select(:invoice_id)
      )
    end

    scope.where(id: subquery.select(:id))
  end

  def with_self_billed(scope)
    scope.where(self_billed: ActiveModel::Type::Boolean.new.cast(filters.self_billed))
  end

  def with_settlements(scope)
    scope.where(
      "EXISTS (
          SELECT 1 FROM invoice_settlements
          WHERE invoice_settlements.target_invoice_id = invoices.id
          AND invoice_settlements.settlement_type IN (?))", valid_settlements
    )
  end

  def issuing_date_from
    @issuing_date_from ||= parse_datetime_filter(:issuing_date_from)
  end

  def issuing_date_to
    @issuing_date_to ||= parse_datetime_filter(:issuing_date_to)
  end

  def valid_settlements
    @valid_settlements ||= Array(filters.settlements)
      .select { |settlement| InvoiceSettlement.settlement_types.key?(settlement) }
  end
end
