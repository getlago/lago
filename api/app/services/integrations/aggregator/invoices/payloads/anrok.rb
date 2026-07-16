# frozen_string_literal: true

module Integrations
  module Aggregator
    module Invoices
      module Payloads
        class Anrok < BasePayload
          def initialize(integration_customer:, invoice:)
            super
          end
        end
      end
    end
  end
end
