# frozen_string_literal: true

module Invoices
  class SyncSalesforceIdService < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:, params:)
      @invoice = invoice
      @params = params
      super
    end

    def call
      return result.not_found_failure!(resource: "invoice") if invoice.nil?
      return result.not_found_failure!(resource: "integration") unless integration

      integration_resource = IntegrationResource.find_or_initialize_by(
        integration:,
        external_id: params[:external_id],
        syncable_id: invoice.id,
        syncable_type: "Invoice",
        resource_type: :invoice
      ) { it.organization_id = invoice.organization_id }

      if integration_resource.new_record?
        integration_resource.save!
      end

      result.invoice = invoice
      result
    end

    private

    attr_reader :invoice, :params

    def integration
      type = Integrations::BaseIntegration.integration_type("salesforce")
      return @integration if defined?(@integration) && @integration&.type == type
      code = params[:integration_code]
      @integration = Integrations::BaseIntegration.find_by(type:, code:, organization: invoice.organization)
    end
  end
end
