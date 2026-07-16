# frozen_string_literal: true

module Invoices
  class GeneratePdfJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PDFS"])
        :pdfs
      else
        :invoices
      end
    end

    retry_on LagoHttpClient::HttpError, wait: :polynomially_longer, attempts: 6

    def perform(invoice)
      result = Invoices::GeneratePdfService.call(invoice:, context: "api")
      result.raise_if_error!
    end
  end
end
