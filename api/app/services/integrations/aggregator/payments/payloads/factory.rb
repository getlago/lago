# frozen_string_literal: true

module Integrations
  module Aggregator
    module Payments
      module Payloads
        class Factory
          def self.new_instance(integration:, payment:)
            case integration.type.to_s
            when "Integrations::NetsuiteIntegration"
              Integrations::Aggregator::Payments::Payloads::Netsuite.new(integration:, payment:)
            when "Integrations::XeroIntegration"
              Integrations::Aggregator::Payments::Payloads::Xero.new(integration:, payment:)
            else
              raise(NotImplementedError)
            end
          end
        end
      end
    end
  end
end
