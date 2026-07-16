# frozen_string_literal: true

module PaymentRequests
  class UpdateService < BaseService
    Result = BaseResult[:payable]

    def initialize(payable:, params:, webhook_notification: false)
      @payable = payable
      @params = params
      @webhook_notification = webhook_notification

      super
    end

    def call
      return result.not_found_failure!(resource: "payment_request") unless payable

      if params.key?(:payment_status) && !valid_payment_status?(params[:payment_status])
        return result.single_validation_failure!(
          field: :payment_status,
          error_code: "value_is_invalid"
        )
      end

      payable.payment_status = params[:payment_status] if params.key?(:payment_status)
      payable.ready_for_payment_processing = params[:ready_for_payment_processing] if params.key?(:ready_for_payment_processing)
      payable.save!

      if payable.saved_change_to_payment_status?
        deliver_webhook if webhook_notification
      end

      result.payable = payable
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :payable, :params, :webhook_notification

    def valid_payment_status?(payment_status)
      PaymentRequest::PAYMENT_STATUS.include?(payment_status&.to_sym)
    end

    def deliver_webhook
      return unless webhook_notification

      SendWebhookJob.perform_later("payment_request.payment_status_updated", payable)
    end
  end
end
