# frozen_string_literal: true

module InvoiceSettlements
  class CreateService < BaseService
    Result = BaseResult[:invoice_settlement]

    def initialize(invoice:, amount_cents:, amount_currency:, source_credit_note: nil, source_payment: nil)
      @invoice = invoice
      @amount_cents = amount_cents
      @amount_currency = amount_currency
      @source_credit_note = source_credit_note
      @source_payment = source_payment

      super
    end

    def call
      validate_single_source!

      ActiveRecord::Base.transaction do
        invoice_settlement = InvoiceSettlement.create!(
          organization_id: invoice.organization_id,
          billing_entity_id: invoice.billing_entity_id,
          target_invoice: invoice,
          source_credit_note: source_credit_note,
          source_payment: source_payment,
          settlement_type: settlement_type,
          amount_cents: amount_cents,
          amount_currency: amount_currency
        )

        result.invoice_settlement = invoice_settlement

        mark_invoice_as_paid! if invoice_fully_settled?
      end

      result
    end

    private

    attr_reader :invoice, :amount_cents, :amount_currency, :source_credit_note, :source_payment

    def validate_single_source!
      if source_credit_note.nil? && source_payment.nil?
        raise ArgumentError, "Must provide either source_credit_note or source_payment"
      end

      if source_credit_note.present? && source_payment.present?
        raise ArgumentError, "Cannot provide both source_credit_note and source_payment"
      end
    end

    def settlement_type
      source_credit_note.present? ? :credit_note : :payment
    end

    def invoice_fully_settled?
      invoice.total_due_amount_cents <= 0
    end

    def mark_invoice_as_paid!
      Invoices::UpdateService.call!(
        invoice: invoice,
        params: {payment_status: :succeeded},
        webhook_notification: true
      )
    end
  end
end
