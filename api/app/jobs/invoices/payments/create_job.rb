# frozen_string_literal: true

module Invoices
  module Payments
    class CreateJob < ApplicationJob
      queue_as do
        if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PAYMENTS"])
          :payments
        else
          :default
        end
      end

      unique :until_executed, on_conflict: :log

      retry_on Invoices::Payments::ConnectionError, wait: :polynomially_longer, attempts: 6
      retry_on Invoices::Payments::RateLimitError, wait: :polynomially_longer, attempts: 6

      def perform(invoice:, payment_provider:, payment_method_params: {})
        Invoices::Payments::CreateService.call!(invoice:, payment_provider:, payment_method_params:)
      end

      def lock_key_arguments
        [arguments.first[:invoice]]
      end
    end
  end
end
