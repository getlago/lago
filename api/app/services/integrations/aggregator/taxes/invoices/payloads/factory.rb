# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module Invoices
        module Payloads
          class Factory
            def self.new_instance(integration:, invoice:, customer:, integration_customer:, fees:)
              case integration.type.to_s
              when "Integrations::AnrokIntegration"
                Integrations::Aggregator::Taxes::Invoices::Payloads::Anrok.new(
                  integration:,
                  invoice:,
                  customer:,
                  integration_customer:,
                  fees:
                )
              when "Integrations::AvalaraIntegration"
                Integrations::Aggregator::Taxes::Invoices::Payloads::Avalara.new(
                  integration:,
                  invoice:,
                  customer:,
                  integration_customer:,
                  fees:
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
end
