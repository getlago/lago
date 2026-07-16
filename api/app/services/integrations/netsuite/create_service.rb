# frozen_string_literal: true

module Integrations
  module Netsuite
    class CreateService < Integrations::CreateService
      attr_reader :params

      def initialize(params:)
        @params = params

        super
      end

      def call
        organization = Organization.find_by(id: params[:organization_id])

        unless organization.netsuite_enabled?
          return result.not_allowed_failure!(code: "premium_integration_missing")
        end

        integration = Integrations::NetsuiteIntegration.new(
          organization:,
          name: params[:name],
          code: params[:code],
          client_id: params[:client_id],
          client_secret: params[:client_secret],
          account_id: params[:account_id],
          token_id: params[:token_id],
          token_secret: params[:token_secret],
          connection_id: params[:connection_id],
          script_endpoint_url: params[:script_endpoint_url],
          sync_credit_notes: ActiveModel::Type::Boolean.new.cast(params[:sync_credit_notes]),
          sync_invoices: ActiveModel::Type::Boolean.new.cast(params[:sync_invoices]),
          sync_payments: ActiveModel::Type::Boolean.new.cast(params[:sync_payments])
        )

        integration.save!

        if integration.type == "Integrations::NetsuiteIntegration"
          Integrations::Aggregator::SendRestletEndpointJob.perform_later(integration:)
          Integrations::Aggregator::PerformSyncJob.set(wait: 2.seconds).perform_later(integration:, sync_items: false)
        end

        result.integration = integration
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end
    end
  end
end
