# frozen_string_literal: true

module V1
  class WalletTransactionSerializer < ModelSerializer
    def serialize
      payload = {
        lago_id: model.id,
        lago_wallet_id: model.wallet_id,
        lago_invoice_id: model.invoice_id,
        lago_credit_note_id: model.credit_note_id,
        lago_voided_invoice_id: model.voided_invoice_id,
        billing_entity_code: billing_entity_code,
        status: model.status,
        source: model.source,
        transaction_status: model.transaction_status,
        transaction_type: model.transaction_type,
        amount: model.amount,
        credit_amount: model.credit_amount,
        remaining_amount_cents: model.remaining_amount_cents,
        remaining_credit_amount: model.remaining_credit_amount,
        priority: model.priority,
        settled_at: model.settled_at&.iso8601,
        failed_at: model.failed_at&.iso8601,
        created_at: model.created_at.iso8601,
        invoice_requires_successful_payment: model.invoice_requires_successful_payment?,
        metadata: model.metadata,
        name: model.name
      }

      payload.merge!(wallet) if include?(:wallet)
      payload.merge!(applied_invoice_custom_sections) if include?(:applied_invoice_custom_sections)
      payload.merge!(payment_method)

      payload
    end

    private

    def billing_entity_code
      (model.billing_entity || model.wallet.billing_entity)&.code
    end

    def wallet
      {
        wallet: ::V1::WalletSerializer.new(model.wallet).serialize
      }
    end

    def applied_invoice_custom_sections
      ::CollectionSerializer.new(
        model.applied_invoice_custom_sections,
        ::V1::AppliedInvoiceCustomSectionSerializer,
        collection_name: "applied_invoice_custom_sections"
      ).serialize
    end

    def payment_method
      {
        payment_method: {
          payment_method_id: model.payment_method_id,
          payment_method_type: model.payment_method_type
        }
      }
    end
  end
end
