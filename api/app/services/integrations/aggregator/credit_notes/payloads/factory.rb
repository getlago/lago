# frozen_string_literal: true

module Integrations
  module Aggregator
    module CreditNotes
      module Payloads
        class Factory
          def self.new_instance(integration_customer:, credit_note:)
            case integration_customer&.integration&.type&.to_s
            when "Integrations::NetsuiteIntegration"
              Integrations::Aggregator::CreditNotes::Payloads::Netsuite.new(integration_customer:, credit_note:)
            when "Integrations::XeroIntegration"
              Integrations::Aggregator::CreditNotes::Payloads::Xero.new(integration_customer:, credit_note:)
            when "Integrations::AnrokIntegration"
              Integrations::Aggregator::CreditNotes::Payloads::Anrok.new(integration_customer:, credit_note:)
            else
              raise(NotImplementedError)
            end
          end
        end
      end
    end
  end
end
