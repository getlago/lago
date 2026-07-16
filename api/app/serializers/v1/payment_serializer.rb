# frozen_string_literal: true

module V1
  class PaymentSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        lago_customer_id: model.payable.customer.id, # TODO: why?
        external_customer_id: model.payable.customer.external_id,
        invoice_ids: invoice_id,
        invoice_numbers: model.invoice_numbers,
        lago_payable_id: model.payable.id,
        payable_type: model.payable_type,

        amount_cents: model.amount_cents,
        amount_currency: model.amount_currency,
        status: model.status, # TODO: Should be `provider_status`
        payment_status: model.payable_payment_status,
        type: model.payment_type,
        reference: model.reference,

        payment_provider_code: model.payment_provider&.code,
        payment_provider_type: model.payment_provider&.type,
        external_payment_id: model.provider_payment_id, # DEPRECATED, use provider_payment_id
        provider_payment_id: model.provider_payment_id,
        provider_customer_id: model.payment_provider_customer&.provider_customer_id, # TODO: remove option?
        next_action: model.provider_payment_data,

        created_at: model.created_at.iso8601
      }

      payload.merge!(payment_receipt) if include?(:payment_receipt)
      payload.merge!(payment_method) if include?(:payment_method) && model.payment_method
      payload
    end

    private

    def payment_method
      {
        payment_method: ::V1::PaymentMethodSerializer.new(model.payment_method).serialize
      }
    end

    def payment_receipt
      {
        payment_receipt: model.payment_receipt ?
          ::V1::PaymentReceiptSerializer.new(model.payment_receipt).serialize :
          {}
      }
    end

    def invoice_id
      model.payable.is_a?(Invoice) ? [model.payable.id] : model.payable.invoice_ids
    end
  end
end
