# frozen_string_literal: true

class TaxesQuery < BaseQuery
  Result = BaseResult[:taxes]
  Filters = BaseFilters[:auto_generated, :applied_to_organization]

  DEFAULT_ORDER = "name"

  def call
    taxes = base_scope.result
    taxes = paginate(taxes)
    taxes = taxes.order(order)
    taxes = apply_consistent_ordering(taxes)

    taxes = with_auto_generated(taxes) if filters.auto_generated.present?
    taxes = with_applied_to_organization(taxes) unless filters.applied_to_organization.nil?

    result.taxes = taxes
    result
  end

  private

  def base_scope
    Tax.where(organization:).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {
      m: "or",
      name_cont: search_term,
      code_cont: search_term
    }
  end

  def order
    Tax::ORDERS.include?(@order) ? @order : DEFAULT_ORDER
  end

  def with_auto_generated(scope)
    scope.where(auto_generated: filters.auto_generated)
  end

  def with_applied_to_organization(scope)
    if filters.applied_to_organization
      scope.joins(:billing_entities_taxes)
        .where(billing_entities_taxes: {billing_entity_id: organization.default_billing_entity.id})
    else
      scope.where.not(id: scope.joins(:billing_entities_taxes)
        .where(billing_entities_taxes: {billing_entity_id: organization.default_billing_entity.id}))
    end
  end
end
