# frozen_string_literal: true

module Invoices
  module Payments
    class RetryAllJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :invoices
        end
      end

      def perform(organization_id:, invoice_ids:)
        result = Invoices::Payments::RetryBatchService.new(organization_id:).call(invoice_ids)
        result.raise_if_error!
      end
    end
  end
end
