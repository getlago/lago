# frozen_string_literal: true

module Integrations
  module Aggregator
    module Contacts
      module Payloads
        class Factory
          def self.new_instance(integration:, customer:, integration_customer:, subsidiary_id:)
            case integration.type.to_s
            when "Integrations::NetsuiteIntegration"
              Integrations::Aggregator::Contacts::Payloads::Netsuite.new(
                integration:,
                customer:,
                integration_customer:,
                subsidiary_id:
              )
            when "Integrations::XeroIntegration"
              Integrations::Aggregator::Contacts::Payloads::Xero.new(
                integration:,
                customer:,
                integration_customer:,
                subsidiary_id:
              )
            when "Integrations::AnrokIntegration"
              Integrations::Aggregator::Contacts::Payloads::Anrok.new(
                integration:,
                customer:,
                integration_customer:,
                subsidiary_id:
              )
            when "Integrations::AvalaraIntegration"
              Integrations::Aggregator::Contacts::Payloads::Avalara.new(
                integration:,
                customer:,
                integration_customer:,
                subsidiary_id:
              )
            when "Integrations::HubspotIntegration"
              Integrations::Aggregator::Contacts::Payloads::Hubspot.new(
                integration:,
                customer:,
                integration_customer:,
                subsidiary_id:
              )
            else
              raise(NotImplementedError)
            end
          end
        end
      end
    end
  end
end
