# frozen_string_literal: true

module PaymentReceipts
  class GeneratePdfJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PDFS"])
        :pdfs
      else
        :low_priority
      end
    end

    retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 6

    def perform(payment_receipt)
      PaymentReceipts::GeneratePdfService.call!(payment_receipt:, context: "api")
    end
  end
end
