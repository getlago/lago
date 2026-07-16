# frozen_string_literal: true

module V1
  module Wallets
    class RecurringTransactionRuleSerializer < ModelSerializer
      def serialize
        payload = {
          lago_id: model.id,
          paid_credits: model.paid_credits,
          granted_credits: model.granted_credits,
          grants_target_top_up: model.grants_target_top_up?,
          interval: model.interval,
          method: model.method,
          started_at: model.started_at&.iso8601,
          expiration_at: model.expiration_at&.iso8601,
          status: model.status,
          target_ongoing_balance: model.target_ongoing_balance,
          threshold_credits: model.threshold_credits,
          trigger: model.trigger,
          created_at: model.created_at.iso8601,
          invoice_requires_successful_payment: model.invoice_requires_successful_payment?,
          transaction_metadata: model.transaction_metadata,
          transaction_name: model.transaction_name,
          ignore_paid_top_up_limits: model.ignore_paid_top_up_limits
        }

        payload.merge!(applied_invoice_custom_sections)
        payload.merge!(payment_method)

        payload
      end

      private

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
end
