# frozen_string_literal: true

class IntegrationItemsQuery < BaseQuery
  Result = BaseResult[:integration_items]
  Filters = BaseFilters[:integration_id, :item_type]

  def call
    integration_items = base_scope.result
    integration_items = paginate(integration_items)
    integration_items = integration_items.order(external_name: :asc)
    integration_items = apply_consistent_ordering(integration_items)

    integration_items = with_integration_id(integration_items) if filters.integration_id.present?
    integration_items = with_item_type(integration_items) unless filters.item_type.nil?

    result.integration_items = integration_items
    result
  end

  private

  def base_scope
    IntegrationItem.joins(:integration).where(integration: {organization_id: organization.id}).ransack(search_params)
  end

  def search_params
    return if search_term.blank?

    {
      m: "or",
      external_name_cont: search_term,
      external_id_cont: search_term,
      external_account_code_cont: search_term
    }
  end

  def with_integration_id(scope)
    scope.where(integration_id: filters.integration_id)
  end

  def with_item_type(scope)
    scope.where(item_type: filters.item_type)
  end
end
