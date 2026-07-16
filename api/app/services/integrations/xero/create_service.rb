# frozen_string_literal: true

module Integrations
  module Xero
    class CreateService < Integrations::CreateService
      def call(**args) # rubocop:disable Cops/ServiceCallCop
        organization = Organization.find_by(id: args[:organization_id])

        unless organization.xero_enabled?
          return result.not_allowed_failure!(code: "premium_integration_missing")
        end

        integration = Integrations::XeroIntegration.new(
          organization:,
          name: args[:name],
          code: args[:code],
          connection_id: args[:connection_id],
          sync_credit_notes: ActiveModel::Type::Boolean.new.cast(args[:sync_credit_notes]),
          sync_invoices: ActiveModel::Type::Boolean.new.cast(args[:sync_invoices]),
          sync_payments: ActiveModel::Type::Boolean.new.cast(args[:sync_payments])
        )

        integration.save!

        Integrations::Aggregator::PerformSyncJob.set(wait: 2.seconds).perform_later(integration:)

        result.integration = integration
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end
    end
  end
end
