# frozen_string_literal: true

module Invoices
  class RetryBatchService < BaseService
    Result = BaseResult[:invoice, :invoices]

    def initialize(organization:)
      @organization = organization

      super
    end

    def call_async
      Invoices::RetryAllJob.perform_later(organization:, invoice_ids: invoices.ids)

      result.invoices = invoices

      result
    end

    def call(invoice_ids)
      processed_invoices = []
      Invoice.where(id: invoice_ids).find_each do |invoice|
        result = Invoices::RetryService.new(invoice:).call

        return result unless result.success?

        processed_invoices << result.invoice
      end

      result.invoices = processed_invoices.compact

      result
    end

    private

    attr_reader :organization

    def invoices
      @invoices ||= organization.invoices.where(status: :failed)
    end
  end
end
