# frozen_string_literal: true

module Integrations
  module Avalara
    class UpdateService < Integrations::UpdateService
      Result = BaseResult[:integration]

      def initialize(integration:, params:)
        @integration = integration
        @params = params

        super
      end

      def call
        return result.not_found_failure!(resource: "integration") unless integration

        unless integration.organization.avalara_enabled?
          return result.not_allowed_failure!(code: "premium_integration_missing")
        end

        integration.name = params[:name] if params.key?(:name)
        integration.code = params[:code] if params.key?(:code)

        integration.save!

        result.integration = integration
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_reader :integration, :params
    end
  end
end
