# frozen_string_literal: true

module IntegrationCollectionMappings
  class DestroyService < BaseService
    def initialize(integration_collection_mapping:)
      @integration_collection_mapping = integration_collection_mapping

      super
    end

    def call
      return result.not_found_failure!(resource: "integration_collection_mapping") unless integration_collection_mapping

      integration_collection_mapping.destroy!

      result.integration_collection_mapping = integration_collection_mapping
      result
    end

    private

    attr_reader :integration_collection_mapping
  end
end
