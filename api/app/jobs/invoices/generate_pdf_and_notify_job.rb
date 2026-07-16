# frozen_string_literal: true

module Invoices
  class GeneratePdfAndNotifyJob < ApplicationJob
    queue_as do
      if ActiveModel::Type::Boolean.new.cast(ENV["SIDEKIQ_PDFS"])
        :pdfs
      else
        :invoices
      end
    end

    def perform(invoice:, email:)
      Invoices::GenerateDocumentsJob.perform_later(invoice:, notify: email)
    end
  end
end
