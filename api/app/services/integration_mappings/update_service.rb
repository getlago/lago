# frozen_string_literal: true

module IntegrationMappings
  class UpdateService < BaseService
    def initialize(integration_mapping:, params:)
      @integration_mapping = integration_mapping
      @params = params

      super
    end

    def call
      return result.not_found_failure!(resource: "integration_mapping") unless integration_mapping

      integration_mapping.external_id = params[:external_id] if params.key?(:external_id)
      integration_mapping.external_account_code = params[:external_account_code] if params.key?(:external_account_code)
      integration_mapping.external_name = params[:external_name] if params.key?(:external_name)

      integration_mapping.save!

      result.integration_mapping = integration_mapping
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :integration_mapping, :params
  end
end
