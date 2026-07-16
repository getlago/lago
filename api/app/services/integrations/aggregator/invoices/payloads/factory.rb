# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Payloads
        class Factory
          def self.new_instance(integration_customer:, invoice:)
            case integration_customer&.integration&.type&.to_s
            when "Integrations::NetsuiteIntegration"
              Integrations::Aggregator::Invoices::Payloads::Netsuite.new(integration_customer:, invoice:)
            when "Integrations::XeroIntegration"
              Integrations::Aggregator::Invoices::Payloads::Xero.new(integration_customer:, invoice:)
            when "Integrations::AnrokIntegration"
              Integrations::Aggregator::Invoices::Payloads::Anrok.new(integration_customer:, invoice:)
            when "Integrations::HubspotIntegration"
              Integrations::Aggregator::Invoices::Payloads::Hubspot.new(integration_customer:, invoice:)
            else
              raise(NotImplementedError)
            end
          end
        end
      end
    end
  end
end
