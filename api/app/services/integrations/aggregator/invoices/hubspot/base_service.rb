# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Hubspot
        class BaseService < Integrations::Aggregator::Invoices::BaseService
          def action_path
            "v1/#{provider}/records"
          end

          private

          def integration_customer
            @integration_customer ||= customer&.integration_customers&.hubspot_kind&.first
          end

          def payload
            Integrations::Aggregator::Invoices::Payloads::Factory.new_instance(integration_customer:, invoice:)
          end
        end
      end
    end
  end
end
