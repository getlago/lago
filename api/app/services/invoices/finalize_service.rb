# frozen_string_literal: true

module Invoices
  class FinalizeService < BaseService
    Result = BaseResult[:invoice]

    def initialize(invoice:)
      @invoice = invoice
      super
    end

    def call
      return result.not_found_failure!(resource: "invoice") if invoice.nil?

      if invoice.finalized?
        result.invoice = invoice
        return result
      end

      invoice.finalized!

      result.invoice = invoice
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :invoice
  end
end
