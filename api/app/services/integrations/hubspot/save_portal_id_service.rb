# frozen_string_literal: true

module Integrations
  module Hubspot
    class SavePortalIdService < BaseService
      Result = BaseResult

      def initialize(integration:)
        @integration = integration
        super
      end

      def call
        return result unless integration.type == "Integrations::HubspotIntegration"
        return result if integration.portal_id.present?

        account_information_result = Integrations::Aggregator::AccountInformationService.call(integration:)

        integration.update!(portal_id: account_information_result.account_information.id)

        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end

      private

      attr_reader :integration
    end
  end
end
