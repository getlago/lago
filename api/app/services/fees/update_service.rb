# frozen_string_literal: true

module Fees
  class UpdateService < BaseService
    Result = BaseResult[:fee]

    def initialize(fee:, params:)
      @fee = fee
      @params = params

      super
    end

    def call
      return result.not_found_failure!(resource: "fee") if fee.nil?

      if params.key?(:payment_status)
        # Once a fee is attached to an invoice, the payment status is irrelevant, it must be the same as the invoice
        return result.not_allowed_failure!(code: "invoiced_fee") if fee.invoice_id

        unless valid_payment_status?(params[:payment_status])
          return result.single_validation_failure!(
            field: :payment_status,
            error_code: "value_is_invalid"
          )
        end

        update_payment_status(params[:payment_status])
      end

      fee.save!

      result.fee = fee
      result
    end

    private

    attr_reader :fee, :params

    def valid_payment_status?(payment_status)
      Fee::PAYMENT_STATUS.include?(payment_status&.to_sym)
    end

    def update_payment_status(payment_status)
      fee.payment_status = payment_status

      # NOTE: A fee can go from pending to failed to pending to succeeded.
      #       We only want the timestamp associated with the current status to be set.
      fee.succeeded_at = nil
      fee.failed_at = nil
      fee.refunded_at = nil

      case payment_status.to_sym
      when :succeeded
        fee.succeeded_at = Time.current
      when :failed
        fee.failed_at = Time.current
      when :refunded
        fee.refunded_at = Time.current
      end
    end
  end
end
