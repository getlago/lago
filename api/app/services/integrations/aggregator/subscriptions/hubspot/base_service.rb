# frozen_string_literal: true

module Integrations
  module Aggregator
    module Subscriptions
      module Hubspot
        class BaseService < Integrations::Aggregator::Subscriptions::BaseService
          def action_path
            "v1/#{provider}/records"
          end

          private

          def integration_customer
            @integration_customer ||= customer&.integration_customers&.hubspot_kind&.first
          end

          def payload
            Integrations::Aggregator::Subscriptions::Payloads::Factory.new_instance(
              integration_customer:,
              subscription:
            )
          end
        end
      end
    end
  end
end
