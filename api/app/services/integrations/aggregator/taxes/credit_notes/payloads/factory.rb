# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module CreditNotes
        module Payloads
          class Factory
            def self.new_instance(integration:, customer:, integration_customer:, credit_note:)
              case integration.type.to_s
              when "Integrations::AnrokIntegration"
                Integrations::Aggregator::Taxes::CreditNotes::Payloads::Anrok.new(
                  integration:,
                  customer:,
                  integration_customer:,
                  credit_note:
                )
              when "Integrations::AvalaraIntegration"
                Integrations::Aggregator::Taxes::CreditNotes::Payloads::Avalara.new(
                  integration:,
                  customer:,
                  integration_customer:,
                  credit_note:
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
