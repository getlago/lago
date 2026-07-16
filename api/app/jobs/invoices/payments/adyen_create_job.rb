# frozen_string_literal: true

module Invoices
  module Payments
    class AdyenCreateJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :providers
        end
      end

      unique :until_executed, on_conflict: :log

      retry_on Faraday::ConnectionFailed, wait: :polynomially_longer, attempts: 6

      def perform(invoice)
        # NOTE: Legacy job, kept only to avoid failure with existing jobs

        Invoices::Payments::CreateService.call!(invoice:, payment_provider: :adyen)
      end
    end
  end
end
