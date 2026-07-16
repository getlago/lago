# frozen_string_literal: true

module Integrations
  module Aggregator
    module Subscriptions
      module Payloads
        class Factory
          def self.new_instance(integration_customer:, subscription:)
            case integration_customer&.integration&.type&.to_s
            when "Integrations::HubspotIntegration"
              Integrations::Aggregator::Subscriptions::Payloads::Hubspot.new(integration_customer:, subscription:)
            else
              raise(NotImplementedError)
            end
          end
        end
      end
    end
  end
end
