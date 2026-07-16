# frozen_string_literal: true

module CreditNotes
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

    def perform(credit_note)
      CreditNotes::GenerateXmlService.call!(credit_note:, context: "api")
      CreditNotes::GeneratePdfService.call!(credit_note:, context: "api")
    end
  end
end
