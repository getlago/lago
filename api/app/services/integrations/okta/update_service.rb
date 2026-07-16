# frozen_string_literal: true

module Integrations
  module Okta
    class UpdateService < Integrations::UpdateService
      def initialize(integration:, params:)
        @integration = integration
        @params = params

        super
      end

      def call
        return result.not_found_failure!(resource: "integration") unless integration

        unless integration.organization.okta_enabled?
          return result.not_allowed_failure!(code: "premium_integration_missing")
        end

        integration.client_id = params[:client_id] if params.key?(:client_id)
        integration.client_secret = params[:client_secret] if params.key?(:client_secret)
        integration.domain = params[:domain] if params.key?(:domain)
        integration.organization_name = params[:organization_name] if params.key?(:organization_name)
        integration.host = params[:host] if params.key?(:host)

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
