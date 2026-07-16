# frozen_string_literal: true

module Payments
  class ManualCreateService < BaseService
    Result = BaseResult[:payment]

    def initialize(organization:, params:)
      @organization = organization
      @params = params
      super
    end

    activity_loggable(
      action: "payment.recorded",
      record: -> { result.payment }
    )

    def call
      check_preconditions
      return result if result.error

      amount_cents = params[:amount_cents]

      ActiveRecord::Base.transaction do
        payment = invoice.payments.create!(
          organization_id: invoice.organization_id,
          customer_id: invoice.customer_id,
          amount_cents:,
          reference: params[:reference],
          amount_currency: invoice.currency,
          status: "succeeded",
          payable_payment_status: "succeeded",
          payment_type: :manual,
          created_at: parsed_paid_at
        )
        result.payment = payment

        total_paid_amount_cents = invoice.payments.where(payable_payment_status: :succeeded).sum(:amount_cents)
        total_applied_from_credit_note = invoice.invoice_settlements.where(settlement_type: :credit_note).sum(:amount_cents)
        update_params = {total_paid_amount_cents: total_paid_amount_cents}
        if (total_paid_amount_cents + total_applied_from_credit_note) == invoice.total_amount_cents
          update_params[:payment_status] = "succeeded"
        end
        Invoices::UpdateService.call!(invoice:, params: update_params, webhook_notification: true)
      end

      after_commit do
        PaymentReceipts::CreateJob.perform_later(result.payment) if organization.issue_receipts_enabled?

        if result.payment&.should_sync_payment?
          Integrations::Aggregator::Payments::CreateJob.perform_later(payment: result.payment)
        end
      end

      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_reader :organization, :params

    def parsed_paid_at
      return nil if params[:paid_at].blank?

      Time.zone.parse(params[:paid_at])
    end

    def invoice
      @invoice ||= organization.invoices.find_by(id: params[:invoice_id])
    end

    def check_preconditions
      return result.single_validation_failure!(error_code: "value_is_mandatory", field: "invoice_id") if params[:invoice_id].blank?
      return result.single_validation_failure!(error_code: "invalid_value", field: "amount_cents") unless valid_amount_cents?
      return result.not_found_failure!(resource: "invoice") unless invoice
      return result if invoice.invoice_type == "advance_charges"

      return result.forbidden_failure! if !License.premium?
      return result.forbidden_failure! unless invoice.allow_manual_payment?

      result.single_validation_failure!(error_code: "invalid_date", field: "paid_at") unless valid_paid_at?
    end

    def valid_paid_at?
      params[:paid_at].blank? || Utils::Datetime.valid_format?(params[:paid_at], format: :any)
    end

    def valid_amount_cents?
      params[:amount_cents].is_a?(Integer) && params[:amount_cents] > 0
    end
  end
end
