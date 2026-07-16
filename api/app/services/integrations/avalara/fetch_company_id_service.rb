# frozen_string_literal: true

module Integrations
  module Avalara
    class FetchCompanyIdService < BaseService
      Result = BaseResult

      def initialize(integration:)
        @integration = integration
        super
      end

      def call
        return result unless integration.type == "Integrations::AvalaraIntegration"
        return result if integration.company_id.present?

        provider_result = Integrations::Aggregator::Taxes::Avalara::FetchCompanyIdService.call(integration:)

        integration.update!(company_id: provider_result.company["id"]) if provider_result.success?

        provider_result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_reader :integration
    end
  end
end
