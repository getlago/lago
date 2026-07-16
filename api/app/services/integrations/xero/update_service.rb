# frozen_string_literal: true

module Integrations
  module Xero
    class UpdateService < Integrations::UpdateService
      def initialize(integration:, params:)
        @integration = integration
        @params = params

        super
      end

      def call
        return result.not_found_failure!(resource: "integration") unless integration

        unless integration.organization.xero_enabled?
          return result.not_allowed_failure!(code: "premium_integration_missing")
        end

        integration.name = params[:name] if params.key?(:name)
        integration.code = params[:code] if params.key?(:code)
        integration.sync_credit_notes = params[:sync_credit_notes] if params.key?(:sync_credit_notes)
        integration.sync_invoices = params[:sync_invoices] if params.key?(:sync_invoices)
        integration.sync_payments = params[:sync_payments] if params.key?(:sync_payments)

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
