# frozen_string_literal: true

module Invoices
  class GenerateXmlJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PDFS"])
        :pdfs
      else
        :invoices
      end
    end

    def perform(invoice)
      result = Invoices::GenerateXmlService.call(invoice:, context: "api")
      result.raise_if_error!
    end
  end
end
