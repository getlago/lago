# frozen_string_literal: true

module Invoices
  class GenerateDocumentsJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PDFS"])
        :pdfs
      else
        :invoices
      end
    end

    retry_on LagoHttpClient::HttpError,
      Errno::ECONNREFUSED,
      Errno::EHOSTUNREACH,
      Net::OpenTimeout,
      Net::ReadTimeout,
      EOFError, wait: :polynomially_longer, attempts: 6

    def perform(invoice:, notify: false)
      Invoices::GenerateXmlService.call!(invoice:)
      Invoices::GeneratePdfService.call!(invoice:)

      Invoices::NotifyJob.perform_later(invoice:) if notify
    end
  end
end
