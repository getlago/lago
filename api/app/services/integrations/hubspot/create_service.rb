# frozen_string_literal: true

module Integrations
  module Hubspot
    class CreateService < Integrations::CreateService
      attr_reader :params

      def initialize(params:)
        @params = params

        super
      end

      def call
        organization = Organization.find_by(id: params[:organization_id])

        unless organization.hubspot_enabled?
          return result.not_allowed_failure!(code: "premium_integration_missing")
        end

        integration = Integrations::HubspotIntegration.new(
          organization:,
          name: params[:name],
          code: params[:code],
          connection_id: params[:connection_id],
          default_targeted_object: params[:default_targeted_object],
          sync_invoices: ActiveModel::Type::Boolean.new.cast(params[:sync_invoices]),
          sync_subscriptions: ActiveModel::Type::Boolean.new.cast(params[:sync_subscriptions])
        )

        integration.save!

        if integration.type == "Integrations::HubspotIntegration"
          Integrations::Aggregator::SyncCustomObjectsAndPropertiesJob.perform_later(integration:)
          Integrations::Hubspot::SavePortalIdJob.perform_later(integration:)
        end

        result.integration = integration
        result
      rescue ActiveRecord::RecordInvalid => e
        result.record_validation_failure!(record: e.record)
      end
    end
  end
end
