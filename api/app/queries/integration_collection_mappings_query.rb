# frozen_string_literal: true

class IntegrationCollectionMappingsQuery < BaseQuery
  Result = BaseResult[:integration_collection_mappings]
  Filters = BaseFilters[:integration_id]

  def call
    integration_collection_mappings = paginate(base_scope)
    integration_collection_mappings = apply_consistent_ordering(integration_collection_mappings)

    integration_collection_mappings = with_integration_id(integration_collection_mappings) if filters.integration_id

    result.integration_collection_mappings = integration_collection_mappings
    result
  end

  private

  def base_scope
    ::IntegrationCollectionMappings::BaseCollectionMapping
      .joins(:integration).where(integration: {organization:})
  end

  def with_integration_id(scope)
    scope.where(integration_id: filters.integration_id)
  end
end
