# frozen_string_literal: true

module PaymentReceipts
  class GenerateDocumentsJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PDFS"])
        :pdfs
      else
        :low_priority
      end
    end

    retry_on LagoHttpClient::HttpError,
      Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH,
      Net::OpenTimeout,
      Net::ReadTimeout,
      EOFError, wait: :polynomially_longer, attempts: 6

    def perform(payment_receipt:, notify: false)
      PaymentReceipts::GenerateXmlService.call(payment_receipt:).raise_if_error!
      PaymentReceipts::GeneratePdfService.call(payment_receipt:).raise_if_error!

      PaymentReceipts::NotifyJob.perform_later(payment_receipt:) if notify
    end
  end
end
