# frozen_string_literal: true

module IntegrationMappings
  class DestroyService < BaseService
    def initialize(integration_mapping:)
      @integration_mapping = integration_mapping

      super
    end

    def call
      return result.not_found_failure!(resource: "integration_mapping") unless integration_mapping

      integration_mapping.destroy!

      result.integration_mapping = integration_mapping
      result
    end

    private

    attr_reader :integration_mapping
  end
end
