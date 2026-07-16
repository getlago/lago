# frozen_string_literal: true

class CustomersQuery < BaseQuery
  Result = BaseResult[:customers]
  Filters = BaseFilters[
    :organization_id,
    :external_id,
    :account_type,
    :billing_entity_ids,
    :with_deleted,
    :active_subscriptions_count_from,
    :active_subscriptions_count_to,
    :countries,
    :states,
    :zipcodes,
    :currencies,
    :has_tax_identification_number,
    :metadata,
    :customer_type,
    :has_customer_type
  ]

  SEARCHABLE_FIELDS = %i[name firstname lastname legal_name external_id email].freeze

  def call
    return result unless validate_filters.success?

    customers = base_scope

    customers = with_external_id(customers) if filters.external_id.present?
    customers = with_customer_type(customers) if filters.customer_type.present? || filters.key?(:has_customer_type)
    customers = with_account_type(customers) if filters.account_type.present?
    customers = with_billing_entity_ids(customers) if filters.billing_entity_ids.present?
    customers = with_active_subscriptions_range(customers) if filters.active_subscriptions_count_from.present? || filters.active_subscriptions_count_to.present?
    customers = with_billing_address_filter(customers) if billing_address_filter?
    customers = with_currencies(customers) if filters.currencies.present?
    customers = with_has_tax_identification_number(customers) if filters.key?(:has_tax_identification_number)
    customers = with_metadata(customers) if filters.metadata.present?

    customers = customers.with_discarded if filters.with_deleted
    customers = paginate(customers)
    customers = apply_consistent_ordering(customers)

    result.customers = customers
    result
  end

  private

  def billing_address_filter?
    filters.countries.present? || filters.states.present? || filters.zipcodes.present?
  end

  def filters_contract
    @filters_contract ||= Queries::CustomersQueryFiltersContract.new
  end

  def base_scope
    scope = Customer.where(organization:)

    return scope if search_term.blank?
    return scope if filters.external_id.present?

    scope.where(id: matching_ids_by_search)
  end

  def matching_ids_by_search
    search_base = Customer.where(organization:)
    search_base = search_base.with_discarded if filters.with_deleted

    escaped_term = "%#{Customer.sanitize_sql_like(search_term)}%"

    branches = SEARCHABLE_FIELDS.map do |field|
      search_base.where("customers.#{field} ILIKE ?", escaped_term).select(:id)
    end

    union_sql = branches.map(&:to_sql).join(" UNION ")
    Customer.unscoped.from("(#{union_sql}) AS customers").select(:id)
  end

  def with_external_id(scope)
    scope.where(external_id: filters.external_id)
  end

  def with_currencies(scope)
    scope.where(currency: filters.currencies)
  end

  def with_billing_address_filter(scope)
    scope = scope.where(country: filters.countries) if filters.countries.present?
    scope = scope.where(state: filters.states) if filters.states.present?
    scope = scope.where(zipcode: filters.zipcodes) if filters.zipcodes.present?
    scope
  end

  def with_metadata(scope)
    presence_filters, absence_filters = filters.metadata.partition { |_k, v| v.present? }

    if presence_filters.any?
      tuples = presence_filters.map { "(?, ?)" }.join(", ")
      subquery = Metadata::CustomerMetadata
        .where(organization_id: organization.id)
        .where("(key, value) IN (#{tuples})", *presence_filters.flatten)
        .group("customer_id")
        .having("COUNT(DISTINCT key) = ?", presence_filters.size)
        .select(:customer_id)

      scope = scope.where(id: subquery)
    end

    if absence_filters.any?
      keys = absence_filters.map { |k, _v| k }
      subquery = Metadata::CustomerMetadata.where(organization_id: organization.id).where(key: keys).select(:customer_id)
      scope = scope.where.not(id: subquery)
    end

    scope
  end

  def with_has_tax_identification_number(scope)
    if has_tax_identification_number?
      scope.where.not(tax_identification_number: nil)
    else
      scope.where(tax_identification_number: nil)
    end
  end

  def with_customer_type(scope)
    if filters.customer_type.present?
      return scope.where(customer_type: filters.customer_type)
    end

    if has_customer_type?
      scope.where.not(customer_type: nil)
    else
      scope.where(customer_type: nil)
    end
  end

  def with_account_type(scope)
    scope.where(account_type: filters.account_type)
  end

  def with_billing_entity_ids(scope)
    scope.where(billing_entity_id: filters.billing_entity_ids)
  end

  def with_active_subscriptions_range(scope)
    active_subscriptions_count = "COUNT(CASE WHEN subscriptions.status = 1 THEN 1 END)"
    count_scope = scope.left_joins(:subscriptions).group("customers.id")

    count_scope = if filters.active_subscriptions_count_from == filters.active_subscriptions_count_to
      count_scope.having("#{active_subscriptions_count} = ?", filters.active_subscriptions_count_from)
    elsif filters.active_subscriptions_count_from.present? && filters.active_subscriptions_count_to.nil?
      count_scope.having("#{active_subscriptions_count} > ?", filters.active_subscriptions_count_from)
    elsif filters.active_subscriptions_count_from.nil? && filters.active_subscriptions_count_to.present?
      count_scope.having("#{active_subscriptions_count} < ?", filters.active_subscriptions_count_to)
    else
      count_scope.having("#{active_subscriptions_count} BETWEEN ? AND ?", filters.active_subscriptions_count_from, filters.active_subscriptions_count_to)
    end

    scope.where(id: count_scope.pluck(:id))
  end

  def has_tax_identification_number?
    ActiveModel::Type::Boolean.new.cast(filters.has_tax_identification_number)
  end

  def has_customer_type?
    ActiveModel::Type::Boolean.new.cast(filters.has_customer_type)
  end
end
