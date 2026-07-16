# frozen_string_literal: true

module Invoices
  module Payments
    class StripeCreateJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :providers
        end
      end

      unique :until_executed, on_conflict: :log

      retry_on ::Stripe::RateLimitError, wait: :polynomially_longer, attempts: 6
      retry_on ::Stripe::APIConnectionError, wait: :polynomially_longer, attempts: 6
      retry_on Invoices::Payments::ConnectionError, wait: :polynomially_longer, attempts: 6
      retry_on Invoices::Payments::RateLimitError, wait: :polynomially_longer, attempts: 6

      def perform(invoice)
        # NOTE: Legacy job, kept only to avoid faileure with existing jobs

        Invoices::Payments::CreateService.call!(invoice:, payment_provider: :stripe)
      end
    end
  end
end
