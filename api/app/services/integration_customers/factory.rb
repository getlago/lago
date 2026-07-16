# frozen_string_literal: true

module IntegrationCustomers
  class Factory
    def self.new_instance(integration:, customer:, subsidiary_id:, **params)
      service_class(integration).new(integration:, customer:, subsidiary_id:, **params)
    end

    def self.service_class(integration)
      case integration&.type&.to_s
      when "Integrations::NetsuiteIntegration"
        IntegrationCustomers::NetsuiteService
      when "Integrations::AnrokIntegration"
        IntegrationCustomers::AnrokService
      when "Integrations::AvalaraIntegration"
        IntegrationCustomers::AvalaraService
      when "Integrations::XeroIntegration"
        IntegrationCustomers::XeroService
      when "Integrations::HubspotIntegration"
        IntegrationCustomers::HubspotService
      when "Integrations::SalesforceIntegration"
        IntegrationCustomers::SalesforceService
      else
        raise(NotImplementedError)
      end
    end
  end
end
