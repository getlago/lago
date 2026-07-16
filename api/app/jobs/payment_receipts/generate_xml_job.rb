# frozen_string_literal: true

module PaymentReceipts
  class GenerateXmlJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PDFS"])
        :pdfs
      else
        :low_priority
      end
    end

    def perform(payment_receipt)
      PaymentReceipts::GenerateXmlService.call!(payment_receipt:, context: "api")
    end
  end
end
