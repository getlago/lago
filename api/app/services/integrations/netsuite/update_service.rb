# frozen_string_literal: true

module Integrations
  module Netsuite
    class UpdateService < Integrations::UpdateService
      def initialize(integration:, params:)
        @integration = integration
        @params = params

        super
      end

      def call
        return result.not_found_failure!(resource: "integration") unless integration

        unless integration.organization.netsuite_enabled?
          return result.not_allowed_failure!(code: "premium_integration_missing")
        end

        old_script_url = integration.script_endpoint_url

        integration.name = params[:name] if params.key?(:name)
        integration.code = params[:code] if params.key?(:code)
        integration.script_endpoint_url = params[:script_endpoint_url] if params.key?(:script_endpoint_url)
        integration.sync_credit_notes = params[:sync_credit_notes] if params.key?(:sync_credit_notes)
        integration.sync_invoices = params[:sync_invoices] if params.key?(:sync_invoices)
        integration.sync_payments = params[:sync_payments] if params.key?(:sync_payments)

        integration.save!

        if integration.type == "Integrations::NetsuiteIntegration" && integration.script_endpoint_url != old_script_url
          Integrations::Aggregator::SendRestletEndpointJob.perform_later(integration:)
          Integrations::Aggregator::PerformSyncJob.set(wait: 2.seconds).perform_later(integration:, sync_items: false)
        end

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
