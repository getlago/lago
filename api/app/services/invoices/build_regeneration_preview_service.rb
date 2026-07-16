# frozen_string_literal: true

module Invoices
  class BuildRegenerationPreviewService < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:)
      @invoice = invoice

      super
    end

    def call
      preview_invoice = invoice.dup

      invoice.fees.each do |fee|
        dup_fee = fee.dup
        dup_fee.invoice = preview_invoice
        preview_invoice.fees << dup_fee

        result = Fees::ApplyTaxesService.call!(fee: dup_fee)
        result.raise_if_error!

        dup_fee.id = fee.id
        dup_fee.applied_taxes.each do |applied_tax|
          applied_tax.fee_id = fee.id
          applied_tax.id = SecureRandom.uuid
        end
      end

      # NOTE: Provider taxes doesn't apply in this service.
      # Since Lago calls external API to compute provider taxes, we want to avoid doing it and have a bad user experience
      # during the invoice regeneration preview.
      result = Invoices::ComputeAmountsFromFees.call(invoice: preview_invoice, provider_taxes: nil)
      result.raise_if_error!

      result.invoice.id = invoice.id
      result.invoice.applied_taxes.each do |applied_tax|
        applied_tax.invoice_id = invoice.id
        applied_tax.id = SecureRandom.uuid
      end

      result
    end

    private

    attr_reader :invoice
  end
end
