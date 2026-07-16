# frozen_string_literal: true

module V1
  module CreditNotes
    class AppliedTaxSerializer < ModelSerializer
      def serialize
        {
          lago_id: model.id,
          lago_credit_note_id: model.credit_note_id,
          lago_tax_id: model.tax_id,
          tax_name: model.tax_name,
          tax_code: model.tax_code,
          tax_rate: model.tax_rate,
          tax_description: model.tax_description,
          base_amount_cents: model.base_amount_cents,
          amount_cents: model.amount_cents,
          amount_currency: model.amount_currency,
          created_at: model.created_at&.iso8601
        }
      end
    end
  end
end
