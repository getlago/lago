# frozen_string_literal: true

module Integrations
  module Aggregator
    module Taxes
      module Invoices
        class CreateJob < ApplicationJob
          queue_as "providers"

          unique :until_executed, on_conflict: :log

          retry_on BaseService::ThrottlingError, wait: :polynomially_longer, attempts: 25
          retry_on(*Integrations::Aggregator::BaseService.retryable_errors, wait: :polynomially_longer, attempts: 6)

          def perform(invoice:)
            Integrations::Aggregator::Taxes::Invoices::CreateService.call!(invoice:, fees: invoice.fees)
          end
        end
      end
    end
  end
end
