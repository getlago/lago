# frozen_string_literal: true

class WalletsQuery < BaseQuery
  Result = BaseResult[:wallets]
  Filters = BaseFilters[:external_customer_id, :currency, :billing_entity_ids]

  def call
    validate_filters
    return result if result.error.present?

    wallets = base_scope

    wallets = with_external_customer_id(wallets) if filters.external_customer_id
    wallets = with_currency(wallets) if filters.currency
    wallets = with_billing_entity_ids(wallets) if filters.billing_entity_ids.present?

    wallets = paginate(wallets)
    wallets = apply_consistent_ordering(wallets)

    result.wallets = wallets
    result
  end

  private

  def base_scope
    organization.wallets
  end

  def with_external_customer_id(scope)
    scope.where(customer_id: customer.select(:id))
  end

  def with_currency(scope)
    scope.where(balance_currency: filters.currency)
  end

  def with_billing_entity_ids(scope)
    scope.joins(:customer).where(
      "COALESCE(wallets.billing_entity_id, customers.billing_entity_id) IN (?)",
      filters.billing_entity_ids
    )
  end

  def validate_filters
    if filters.to_h.key? :external_customer_id
      result.not_found_failure!(resource: "customer") unless customer.exists?
    end
  end

  def customer
    organization.customers.where(external_id: filters.external_customer_id)
  end
end
