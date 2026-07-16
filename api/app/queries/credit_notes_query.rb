# frozen_string_literal: true

class CreditNotesQuery < BaseQuery
  Result = BaseResult[:credit_notes]
  Filters = BaseFilters[
    :billing_entity_ids,
    :currency,
    :customer_external_id,
    :customer_id,
    :invoice_number,
    :issuing_date_from,
    :issuing_date_to,
    :amount_from,
    :amount_to,
    :self_billed,
    :credit_status,
    :reason,
    :refund_status,
    :types
  ]

  def initialize(includes: [], **args)
    @includes = includes
    super(**args)
  end

  def call
    credit_notes = base_scope.result

    credit_notes = with_billing_entity_ids(credit_notes) if filters.billing_entity_ids.present?
    credit_notes = with_currency(credit_notes) if filters.currency.present?
    credit_notes = with_customer_external_id(credit_notes) if filters.customer_external_id
    credit_notes = with_customer_id(credit_notes) if filters.customer_id.present?
    credit_notes = with_reason(credit_notes) if valid_reasons.present?
    credit_notes = with_credit_status(credit_notes) if valid_credit_statuses.present?
    credit_notes = with_refund_status(credit_notes) if valid_refund_statuses.present?
    credit_notes = with_types(credit_notes) if valid_types.present?
    credit_notes = with_invoice_number(credit_notes) if filters.invoice_number.present?
    credit_notes = with_issuing_date_range(credit_notes) if filters.issuing_date_from || filters.issuing_date_to
    credit_notes = with_amount_range(credit_notes) if filters.amount_from.present? || filters.amount_to.present?
    credit_notes = with_self_billed_invoice(credit_notes) unless filters.self_billed.nil?

    credit_notes = paginate(credit_notes)
    credit_notes = apply_consistent_ordering(credit_notes)

    result.credit_notes = credit_notes
    result
  rescue BaseService::FailedResult
    result
  end

  private

  def base_scope
    scope = CreditNote
      .where(organization:)
      .finalized

    scope = scope.includes(*@includes) if @includes.present?
    scope.ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    terms = {
      m: "or",
      id_cont: search_term,
      number_cont: search_term
    }

    return terms if filters.customer_id.present?

    terms.merge(
      customer_name_cont: search_term,
      customer_firstname_cont: search_term,
      customer_lastname_cont: search_term,
      customer_external_id_cont: search_term,
      customer_email_cont: search_term
    )
  end

  def with_currency(scope)
    scope.where(total_amount_currency: filters.currency)
  end

  def with_customer_external_id(scope)
    scope.joins(:customer).where(customers: {external_id: filters.customer_external_id})
  end

  def with_customer_id(scope)
    scope.where(customer_id: filters.customer_id)
  end

  def with_reason(scope)
    scope.where(reason: valid_reasons)
  end

  def with_credit_status(scope)
    scope.where(credit_status: valid_credit_statuses)
  end

  def with_refund_status(scope)
    scope.where(refund_status: valid_refund_statuses)
  end

  def with_types(scope)
    predicates = []

    if valid_types.include?("credit")
      predicates << "credit_notes.credit_amount_cents > 0"
    end

    if valid_types.include?("refund")
      predicates << "credit_notes.refund_amount_cents > 0"
    end

    if valid_types.include?("offset")
      predicates << "credit_notes.offset_amount_cents > 0"
    end

    return scope.none if predicates.empty?

    scope.where(predicates.join(" OR "))
  end

  def with_invoice_number(scope)
    scope.joins(:invoice).where(invoices: {number: filters.invoice_number})
  end

  def with_issuing_date_range(scope)
    scope = scope.where(issuing_date: issuing_date_from..) if filters.issuing_date_from
    scope = scope.where(issuing_date: ..issuing_date_to) if filters.issuing_date_to
    scope
  end

  def with_amount_range(scope)
    scope = scope.where("credit_notes.total_amount_cents >= ?", filters.amount_from) if filters.amount_from
    scope = scope.where("credit_notes.total_amount_cents <= ?", filters.amount_to) if filters.amount_to
    scope
  end

  def with_self_billed_invoice(scope)
    scope
      .joins(:invoice)
      .where(invoices: {
        self_billed: ActiveModel::Type::Boolean.new.cast(filters.self_billed)
      })
  end

  def with_billing_entity_ids(scope)
    scope.joins(:invoice).where(invoices: {billing_entity_id: filters.billing_entity_ids})
  end

  def issuing_date_from
    @issuing_date_from ||= parse_datetime_filter(:issuing_date_from)
  end

  def issuing_date_to
    @issuing_date_to ||= parse_datetime_filter(:issuing_date_to)
  end

  def valid_credit_statuses
    @valid_credit_statuses ||= Array(filters.credit_status)
      .select { |credit_status| CreditNote.credit_statuses.key?(credit_status) }
  end

  def valid_refund_statuses
    @valid_refund_statuses ||= Array(filters.refund_status)
      .select { |refund_status| CreditNote.refund_statuses.key?(refund_status) }
  end

  def valid_reasons
    @valid_reasons ||= Array(filters.reason)
      .select { |reason| CreditNote.reasons.key?(reason) }
  end

  def valid_types
    @valid_types ||= Array(filters.types)
      .select { |type| CreditNote::TYPES.include?(type) }
  end
end
