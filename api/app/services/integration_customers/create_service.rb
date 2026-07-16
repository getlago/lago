# frozen_string_literal: true

module IntegrationCustomers
  class CreateService < BaseService
    def initialize(params:, integration:, customer:)
      @customer = customer
      super(params:, integration:)
    end

    def call
      result = super
      return result if result.error

      res = if external_customer_id.present?
        link_customer!
      elsif sync_with_provider
        sync_customer!
      end
      return res if res&.error

      result
    rescue ActiveRecord::RecordNotUnique
      # Avoid raising on race conditions when multiple requests are made at the same time
      result.integration_customer = IntegrationCustomers::BaseCustomer.find_by(
        customer:, integration:, type: customer_type
      )
      result
    end

    private

    attr_reader :customer

    def sync_customer!
      integration_customer_service = IntegrationCustomers::Factory.new_instance(
        integration:, customer:, subsidiary_id:, **params
      )

      return result unless integration_customer_service

      sync_result = integration_customer_service.create

      return sync_result if sync_result.error

      result.integration_customer = sync_result.integration_customer
      result
    end

    def link_customer!
      sync_with_provider = integration&.type&.to_s == "Integrations::SalesforceIntegration"

      new_integration_customer = IntegrationCustomers::BaseCustomer.create!(
        organization_id: integration.organization_id,
        integration:,
        customer:,
        external_customer_id: params[:external_customer_id],
        type: customer_type,
        sync_with_provider: sync_with_provider
      )

      if integration&.type&.to_s == "Integrations::NetsuiteIntegration"
        new_integration_customer.subsidiary_id = subsidiary_id
        new_integration_customer.save!
      end

      if integration&.type&.to_s == "Integrations::HubspotIntegration"
        new_integration_customer.targeted_object = targeted_object
        new_integration_customer.save!
      end

      result.integration_customer = new_integration_customer
      result
    end
  end
end
