# frozen_string_literal: true

module IntegrationCollectionMappings
  class UpdateService < BaseService
    def initialize(integration_collection_mapping:, params:)
      @integration_collection_mapping = integration_collection_mapping
      @params = params

      super
    end

    def call
      return result.not_found_failure!(resource: "integration_collection_mapping") unless integration_collection_mapping

      integration_collection_mapping.external_id = params[:external_id] if params.key?(:external_id)
      if params.key?(:external_account_code)
        integration_collection_mapping.external_account_code = params[:external_account_code]
      end
      integration_collection_mapping.external_name = params[:external_name] if params.key?(:external_name)
      integration_collection_mapping.tax_nexus = params[:tax_nexus] if params.key?(:tax_nexus)
      integration_collection_mapping.tax_code = params[:tax_code] if params.key?(:tax_code)
      integration_collection_mapping.tax_type = params[:tax_type] if params.key?(:tax_type)
      integration_collection_mapping.currencies = params[:currencies] if params.key?(:currencies)

      integration_collection_mapping.save!

      result.integration_collection_mapping = integration_collection_mapping
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :integration_collection_mapping, :params
  end
end
