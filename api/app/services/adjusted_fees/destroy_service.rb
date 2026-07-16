# frozen_string_literal: true

module AdjustedFees
  class DestroyService < BaseService
    Result = BaseResult[:fee]

    def initialize(fee:)
      @fee = fee

      super
    end

    def call
      return result.not_found_failure!(resource: "fee") unless fee
      return result.not_found_failure!(resource: "adjusted_fee") unless fee.adjusted_fee

      fee.adjusted_fee.destroy!

      refresh_result = Invoices::RefreshDraftService.call(invoice: fee.invoice)
      refresh_result.raise_if_error!

      result.fee = fee
      result
    end

    private

    attr_reader :fee
  end
end
